class Admin::ProceduresController < AdminController
  include SmartListing::Helper::ControllerExtensions
  helper SmartListing::Helper

  before_action :retrieve_procedure, only: [:show, :edit, :delete_logo, :delete_deliberation, :delete_notice, :monavis, :update_monavis, :publish_validate, :publish]

  def index
    if current_administrateur.procedures.count != 0
      @procedures = smart_listing_create :procedures,
        current_administrateur.procedures.publiees.order(published_at: :desc),
        partial: "admin/procedures/list",
        array: true

      active_class
    else
      redirect_to new_from_existing_admin_procedures_path
    end
  end

  def archived
    @procedures = smart_listing_create :procedures,
      current_administrateur.procedures.archivees.order(published_at: :desc),
      partial: "admin/procedures/list",
      array: true

    archived_class

    render 'index'
  end

  def draft
    @procedures = smart_listing_create :procedures,
      current_administrateur.procedures.brouillons.order(created_at: :desc),
      partial: "admin/procedures/list",
      array: true

    draft_class

    render 'index'
  end

  def show
    if @procedure.brouillon?
      @procedure_lien = commencer_test_url(path: @procedure.path)
    else
      @procedure_lien = commencer_url(path: @procedure.path)
    end
    @procedure.path = @procedure.suggested_path(current_administrateur)
    @current_administrateur = current_administrateur
  end

  def edit
  end

  def destroy
    procedure = current_administrateur.procedures.find(params[:id])

    if procedure.publiee_ou_archivee?
      return render json: {}, status: 401
    end

    procedure.reset!
    procedure.destroy

    flash.notice = 'Démarche supprimée'
    redirect_to admin_procedures_draft_path
  end

  def new
    @procedure ||= Procedure.new(for_individual: true)
  end

  def create
    @procedure = Procedure.new(procedure_params.merge(administrateurs: [current_administrateur]))

    if !@procedure.save
      flash.now.alert = @procedure.errors.full_messages
      render 'new'
    else
      flash.notice = 'Démarche enregistrée.'
      current_administrateur.instructeur.assign_to_procedure(@procedure)

      redirect_to champs_procedure_path(@procedure)
    end
  end

  def update
    @procedure = current_administrateur.procedures.find(params[:id])

    if !@procedure.update(procedure_params)
      flash.now.alert = @procedure.errors.full_messages
      render 'edit'
    elsif @procedure.brouillon?
      reset_procedure
      flash.notice = 'Démarche modifiée. Tous les dossiers de cette démarche ont été supprimés.'
      redirect_to edit_admin_procedure_path(id: @procedure.id)
    else
      flash.notice = 'Démarche modifiée.'
      redirect_to edit_admin_procedure_path(id: @procedure.id)
    end
  end

  def publish_validate
    @procedure.assign_attributes(publish_params)
  end

  def publish
    @procedure.assign_attributes(publish_params)

    @procedure.publish_or_reopen!(current_administrateur)

    flash.notice = "Démarche publiée"
    redirect_to admin_procedures_path
  rescue ActiveRecord::RecordInvalid
    render 'publish_validate', formats: :js
  end

  def transfer
    admin = Administrateur.find_by(email: params[:email_admin].downcase)

    if admin.nil?
      render '/admin/procedures/transfer', formats: 'js', status: 404
    else
      procedure = current_administrateur.procedures.find(params[:procedure_id])
      procedure.clone(admin, false)

      flash.now.notice = "La démarche a correctement été clonée vers le nouvel administrateur."

      render '/admin/procedures/transfer', formats: 'js', status: 200
    end
  end

  def archive
    procedure = current_administrateur.procedures.find(params[:procedure_id])
    procedure.archive!

    flash.notice = "Démarche archivée"
    redirect_to admin_procedures_path

  rescue ActiveRecord::RecordNotFound
    flash.alert = 'Démarche inexistante'
    redirect_to admin_procedures_path
  end

  def clone
    procedure = Procedure.find(params[:procedure_id])
    new_procedure = procedure.clone(current_administrateur, cloned_from_library?)

    if new_procedure.valid?
      flash.notice = 'Démarche clonée'
      redirect_to edit_admin_procedure_path(id: new_procedure.id)
    else
      if cloned_from_library?
        flash.alert = new_procedure.errors.full_messages
        redirect_to new_from_existing_admin_procedures_path
      else
        flash.alert = new_procedure.errors.full_messages
        redirect_to admin_procedures_path
      end
    end

  rescue ActiveRecord::RecordNotFound
    flash.alert = 'Démarche inexistante'
    redirect_to admin_procedures_path
  end

  SIGNIFICANT_DOSSIERS_THRESHOLD = 30

  def new_from_existing
    significant_procedure_ids = Procedure
      .publiees_ou_archivees
      .joins(:dossiers)
      .group("procedures.id")
      .having("count(dossiers.id) >= ?", SIGNIFICANT_DOSSIERS_THRESHOLD)
      .pluck('procedures.id')

    @grouped_procedures = Procedure
      .includes(:administrateurs, :service)
      .where(id: significant_procedure_ids)
      .group_by(&:organisation_name)
      .sort_by { |_, procedures| procedures.first.created_at }
    render layout: 'application'
  end

  def monavis
  end

  def update_monavis
    if !@procedure.update(procedure_params)
      flash.now.alert = @procedure.errors.full_messages
    else
      flash.notice = 'le champ MonAvis a bien été mis à jour'
    end
    render 'monavis'
  end

  def active_class
    @active_class = 'active'
  end

  def archived_class
    @archived_class = 'active'
  end

  def draft_class
    @draft_class = 'active'
  end

  def delete_logo
    @procedure.logo.purge_later

    flash.notice = 'le logo a bien été supprimé'
    redirect_to edit_admin_procedure_path(@procedure)
  end

  def delete_deliberation
    @procedure.deliberation.purge_later

    flash.notice = 'la délibération a bien été supprimée'
    redirect_to edit_admin_procedure_path(@procedure)
  end

  def delete_notice
    @procedure.notice.purge_later

    flash.notice = 'la notice a bien été supprimée'
    redirect_to edit_admin_procedure_path(@procedure)
  end

  private

  def cloned_from_library?
    params[:from_new_from_existing].present?
  end

  def publish_params
    params.permit(:path, :lien_site_web)
  end

  def procedure_params
    editable_params = [:libelle, :description, :organisation, :direction, :lien_site_web, :cadre_juridique, :deliberation, :notice, :web_hook_url, :euro_flag, :logo, :auto_archive_on, :monavis_embed]
    permited_params = if @procedure&.locked?
      params.require(:procedure).permit(*editable_params)
    else
      params.require(:procedure).permit(*editable_params, :duree_conservation_dossiers_dans_ds, :duree_conservation_dossiers_hors_ds, :for_individual, :path)
    end
    permited_params
  end
end
