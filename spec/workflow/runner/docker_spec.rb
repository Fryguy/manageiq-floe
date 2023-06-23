RSpec.describe Floe::Workflow::Runner::Docker do
  require "securerandom"

  let(:subject)        { described_class.new(runner_options) }
  let(:runner_options) { {} }

  let(:subject)      { described_class.new }
  let(:container_id) { SecureRandom.hex }

  describe "#run_async!" do
    it "raises an exception without a resource" do
      expect { subject.run_async!(nil) }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "raises an exception for an invalid resource uri" do
      expect { subject.run_async!("arn:abcd:efgh") }.to raise_error(ArgumentError, "Invalid resource")
    end

    it "calls docker run with the image name" do
      stub_good_run!("docker", :params => ["run", :detach, "hello-world:latest"], :output => container_id)

      subject.run_async!("docker://hello-world:latest")
    end

    it "passes environment variables to docker run" do
      stub_good_run!("docker", :params => ["run", :detach, [:e, "FOO=BAR"], "hello-world:latest"], :output => container_id)

      subject.run_async!("docker://hello-world:latest", {"FOO" => "BAR"})
    end

    it "passes a secrets volume to docker run" do
      stub_good_run!("docker", :params => ["run", :detach, [:e, "FOO=BAR"], [:e, "SECRETS=/run/secrets"], [:v, a_string_including(":/run/secrets")], "hello-world:latest"], :output => container_id)

      subject.run_async!("docker://hello-world:latest", {"FOO" => "BAR"}, {"luggage_password" => "12345"})
    end
  end

  describe "#running?" do
    it "returns true when running" do
      stub_good_run!("docker", :params => ["inspect", container_id], :output => "[{\"State\": {\"Running\": true}}]")
      expect(subject.running?(container_id)).to be_truthy
    end

    it "returns false when completed" do
      stub_good_run!("docker", :params => ["inspect", container_id], :output => "[{\"State\": {\"Running\": false, \"ExitCode\": 0}}]")
      expect(subject.running?(container_id)).to be_falsey
    end
  end

  describe "#success?" do
    it "returns true when successful" do
      stub_good_run!("docker", :params => ["inspect", container_id], :output => "[{\"State\": {\"Running\": false, \"ExitCode\": 0}}]")
      expect(subject.success?(container_id)).to be_truthy
    end

    it "returns false when unsuccessful" do
      stub_good_run!("docker", :params => ["inspect", container_id], :output => "[{\"State\": {\"Running\": false, \"ExitCode\": 1}}]")
      expect(subject.success?(container_id)).to be_falsey
    end
  end

  describe "#output" do
    it "returns log output" do
      stub_good_run!("docker", :params => ["logs", container_id], :output => "hello, world!")
      expect(subject.output(container_id)).to eq("hello, world!")
    end

    it "raises an exception when getting pod logs fails" do
      stub_bad_run!("docker", :params => ["logs", container_id])
      expect { subject.output(container_id) }.to raise_error(AwesomeSpawn::CommandResultError, /docker exit code: 1/)
    end
  end

  describe "#cleanup" do
    let(:secrets_file) { double("Tempfile") }

    it "deletes the container and secret" do
      stub_good_run!("docker", :params => ["rm", container_id])
      expect(secrets_file).to receive(:close!)
      subject.cleanup(container_id, secrets_file)
    end

    it "doesn't delete the secret_file if not passed" do
      stub_good_run!("docker", :params => ["rm", container_id])
      subject.cleanup(container_id, nil)
    end

    it "deletes the secrets file if deleting the container fails" do
      stub_bad_run!("docker", :params => ["rm", container_id])
      expect(secrets_file).to receive(:close!)
      subject.cleanup(container_id, secrets_file)
    end

    context "with network=host" do
      let(:runner_options) { {"network" => "host"} }

      it "calls docker run with --net host" do
        stub_good_run!("docker", :params => ["run", :rm, "hello-world:latest"])

        subject.run!("docker://hello-world:latest")
      end
    end
  end
end
