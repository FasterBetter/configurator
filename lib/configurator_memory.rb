# frozen_string_literal: true

require 'lifecycle/vm_memory'

require 'configurator_types'

class ConfiguratorMemory < Lifecycle::VmMemory
  attr_accessor :argv, :env, :early_exit, :configuration_directory,
                :runtime_directory, :logs_directory, :run_count, :profile_defs,
                :template_defs, :service_defs, :dependencies, :refresh_interval,
                :client_id, :compiled_templates, :applied_profiles, :applying_profile,
                :generated_templates, :services_to_reload, :profiles_to_apply,
                :last_refresh_time, :next_state, :retry_count, :retries_left, :retry_wait

  def initialize(
    argv: [],
    env: {},
    early_exit: false,
    configuration_directory: nil,
    runtime_directory: nil,
    logs_directory: nil,
    run_count: 0,
    profile_defs: {},
    template_defs: {},
    service_defs: {},
    dependencies: {},
    refresh_interval: 5,
    client_id: '',
    logger: nil,
    compiled_templates: {},
    applied_profiles: {},
    profiles_to_apply: [],
    applying_profile: nil,
    generated_templates: {},
    services_to_reload: Set.new,
    last_refresh_time: 0,
    next_state: :running,
    retry_count: 3,
    retries_left: 3,
    retry_wait: 2
  )
    super()

    @argv = argv
    @env = env
    @early_exit = early_exit
    @configuration_directory = configuration_directory
    @runtime_directory = runtime_directory
    @logs_directory = logs_directory
    @run_count = run_count
    @profile_defs = profile_defs
    @template_defs = template_defs
    @service_defs = service_defs
    @dependencies = dependencies
    @refresh_interval = refresh_interval
    @client_id = client_id
    @logger = logger
    @compiled_templates = compiled_templates
    @applied_profiles = applied_profiles
    @profiles_to_apply = profiles_to_apply
    @applying_profile = applying_profile
    @generated_templates = generated_templates
    @services_to_reload = services_to_reload
    @last_refresh_time = last_refresh_time
    @next_state = next_state
    @retry_count = retry_count
    @retries_left = retries_left
    @retry_wait = retry_wait
  end
end
