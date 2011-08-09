require 'spec_helper'

describe Err do

  context 'validations' do
    it 'requires a klass' do
      err = Factory.build(:err, :klass => nil)
      err.should_not be_valid
      err.errors[:klass].should include("can't be blank")
    end

    it 'requires an environment' do
      err = Factory.build(:err, :environment => nil)
      err.should_not be_valid
      err.errors[:environment].should include("can't be blank")
    end
  end

  context '#last_notice_at' do
    it "returns the created_at timestamp of the latest notice" do
      err = Factory(:err)
      err.last_notice_at.should be_nil

      notice1 = Factory(:notice, :err => err)
      err.last_notice_at.should == notice1.created_at

      notice2 = Factory(:notice, :err => err)
      err.last_notice_at.should == notice2.created_at
    end
  end

  context '#message' do
    it "returns klass by default" do
      err = Factory(:err)
      err.message.should == err.klass
    end

    it 'returns the message from the first notice' do
      err = Factory(:err)
      notice1 = Factory(:notice, :err => err, :message => 'ERR 1')
      notice2 = Factory(:notice, :err => err, :message => 'ERR 2')
      err.message.should == notice1.message
    end

    it "adding a notice caches its message" do
      err = Factory(:err)
      lambda {
        notice1 = Factory(:notice, :err => err, :message => 'ERR 1')}.should change(err, :message).from(err.klass).to('ERR 1')
    end
  end

  context 'being created' do
    context 'when the app has err notifications set to false' do
      it 'should not send an email notification' do
        app = Factory(:app_with_watcher, :notify_on_errs => false)
        Mailer.should_not_receive(:err_notification)
        Factory(:err, :problem => Factory(:problem, :app => app))
      end
    end
  end

  context "notice counter cache" do

    before do
      @app = Factory(:app)
      @err = Factory(:err, :problem => Factory(:problem, :app => @app))
    end

    it "#notices_count returns 0 by default" do
      @err.notices_count.should == 0
    end

    it "adding a notice increases #notices_count by 1" do
      lambda {
        notice1 = Factory(:notice, :err => @err, :message => 'ERR 1')}.should change(@err, :notices_count).from(0).to(1)
    end

    it "removing a notice decreases #notices_count by 1" do
      notice1 = Factory(:notice, :err => @err, :message => 'ERR 1')
      lambda {
        @err.notices.first.destroy
      }.should change(@err, :notices_count).from(1).to(0)
    end
  end
end
