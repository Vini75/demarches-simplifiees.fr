require 'rails_helper'

RSpec.describe Avis, type: :model do
  let(:claimant) { create(:instructeur) }

  describe '#email_to_display' do
    let(:invited_email) { 'invited@avis.com' }
    let!(:avis) do
      avis = create(:avis, email: invited_email, dossier: create(:dossier))
      avis.instructeur = nil
      avis
    end

    subject { avis.email_to_display }

    context 'when instructeur is not known' do
      it { is_expected.to eq(invited_email) }
    end

    context 'when instructeur is known' do
      let!(:avis) { create(:avis, email: nil, instructeur: create(:instructeur), dossier: create(:dossier)) }

      it { is_expected.to eq(avis.instructeur.email) }
    end
  end

  describe '.by_latest' do
    context 'with 3 avis' do
      let!(:avis) { create(:avis) }
      let!(:avis2) { create(:avis, updated_at: 4.hours.ago) }
      let!(:avis3) { create(:avis, updated_at: 3.hours.ago) }

      subject { Avis.by_latest }

      it { expect(subject).to eq([avis, avis3, avis2]) }
    end
  end

  describe ".link_avis_to_instructeur" do
    let(:instructeur) { create(:instructeur) }

    subject { Avis.link_avis_to_instructeur(instructeur) }

    context 'when there are 2 avis linked by email to a instructeur' do
      let!(:avis) { create(:avis, email: instructeur.email, instructeur: nil) }
      let!(:avis2) { create(:avis, email: instructeur.email, instructeur: nil) }

      before do
        subject
        avis.reload
        avis2.reload
      end

      it { expect(avis.email).to be_nil }
      it { expect(avis.instructeur).to eq(instructeur) }
      it { expect(avis2.email).to be_nil }
      it { expect(avis2.instructeur).to eq(instructeur) }
    end
  end

  describe '.avis_exists_and_email_belongs_to_avis?' do
    let(:dossier) { create(:dossier) }
    let(:invited_email) { 'invited@avis.com' }
    let!(:avis) { create(:avis, email: invited_email, dossier: dossier) }

    subject { Avis.avis_exists_and_email_belongs_to_avis?(avis_id, email) }

    context 'when the avis is unknown' do
      let(:avis_id) { 666 }
      let(:email) { 'unknown@mystery.com' }

      it { is_expected.to be false }
    end

    context 'when the avis is known' do
      let(:avis_id) { avis.id }

      context 'when the email belongs to the invitation' do
        let(:email) { invited_email }
        it { is_expected.to be true }
      end

      context 'when the email is unknown' do
        let(:email) { 'unknown@mystery.com' }
        it { is_expected.to be false }
      end
    end
  end

  describe '#notify_instructeur' do
    context 'when an avis is created' do
      before do
        avis_invitation_double = double('avis_invitation', deliver_later: true)
        allow(AvisMailer).to receive(:avis_invitation).and_return(avis_invitation_double)
        Avis.create(claimant: claimant, email: 'email@l.com')
      end

      it { expect(AvisMailer).to have_received(:avis_invitation) }
    end
  end

  describe '#try_to_assign_instructeur' do
    let!(:instructeur) { create(:instructeur) }
    let(:avis) { Avis.create(claimant: claimant, email: email, dossier: create(:dossier)) }

    context 'when the email belongs to a instructeur' do
      let(:email) { instructeur.email }

      it { expect(avis.instructeur).to eq(instructeur) }
      it { expect(avis.email).to be_nil }
    end

    context 'when the email does not belongs to a instructeur' do
      let(:email) { 'unknown@email' }

      it { expect(avis.instructeur).to be_nil }
      it { expect(avis.email).to eq(email) }
    end
  end

  describe "email sanitization" do
    subject { Avis.create(claimant: claimant, email: email, dossier: create(:dossier), instructeur: create(:instructeur)) }

    context "when there is no email" do
      let(:email) { nil }

      it { expect(subject.email).to be_nil }
    end

    context "when the email is in lowercase" do
      let(:email) { "toto@tps.fr" }

      it { expect(subject.email).to eq("toto@tps.fr") }
    end

    context "when the email is not in lowercase" do
      let(:email) { "TOTO@tps.fr" }

      it { expect(subject.email).to eq("toto@tps.fr") }
    end

    context "when the email has some spaces before and after" do
      let(:email) { "  toto@tps.fr  " }

      it { expect(subject.email).to eq("toto@tps.fr") }
    end
  end
end
