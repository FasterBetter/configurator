$LOAD_PATH << File.join(__dir__, 'lib')

require_relative 'lib/configurator'
require_relative 'lib/configurator_memory'

require 'logsformyfamily'

LogsForMyFamily.configure do |config|
  config.version = Configurator::VERSION
  config.app_name = Configurator.name
end

logger = LogsForMyFamily::Logger.new
logger.backends = [StdoutLogWriter.new]
log_level = ENV['CONFIGURATOR_LOG_LEVEL']&.to_sym
if log_level && LogsForMyFamily::Logger::LEVELS.include?(log_level)
  logger.filter_level(log_level)
elsif log_level
  $stderr.puts("Unknown log level requested in CONFIGURATOR_LOG_LEVEL: #{log_level}")
end

memory = ConfiguratorMemory.new(argv: ARGV, env: ENV, logger: logger)
vm = Configurator.new(memory)
vm.call

if vm.errors?
  warn "Errored executing #{vm.error_op.class.name}"
  warn "Errors: #{vm.errors}"

  if vm.recovery_errors?
    warn ''
    warn "Errors recovering from error. Errored executing recovery #{vm.current_op.class.name}"
    warn "Errors: #{vm.recovery_errors}"
  end

  exit 1
end
