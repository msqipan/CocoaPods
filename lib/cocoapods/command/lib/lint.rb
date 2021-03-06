module Pod
  class Command
    class Lib < Command
      class Lint < Lib
        self.summary = 'Validates a Pod'

        self.description = <<-DESC
          Validates the Pod using the files in the working directory.
        DESC

        def self.options
          [
            ['--quick', 'Lint skips checks that would require to download and build the spec'],
            ['--allow-warnings', 'Lint validates even if warnings are present'],
            ['--subspec=NAME', 'Lint validates only the given subspec'],
            ['--no-subspecs', 'Lint skips validation of subspecs'],
            ['--no-clean', 'Lint leaves the build directory intact for inspection'],
            ['--fail-fast', 'Lint stops on the first failing platform or subspec'],
            ['--use-libraries', 'Lint uses static libraries to install the spec'],
            ['--sources=https://github.com/artsy/Specs,master', 'The sources from which to pull dependent pods ' \
             '(defaults to https://github.com/CocoaPods/Specs.git). ' \
             'Multiple sources must be comma-delimited.'],
            ['--private', 'Lint skips checks that apply only to public specs'],
            ['--swift-version=VERSION', 'The SWIFT_VERSION that should be used to lint the spec. ' \
             'This takes precedence over a .swift-version file.'],
          ].concat(super)
        end

        def initialize(argv)
          @quick           = argv.flag?('quick')
          @allow_warnings  = argv.flag?('allow-warnings')
          @clean           = argv.flag?('clean', true)
          @fail_fast       = argv.flag?('fail-fast', false)
          @subspecs        = argv.flag?('subspecs', true)
          @only_subspec    = argv.option('subspec')
          @use_frameworks  = !argv.flag?('use-libraries')
          @source_urls     = argv.option('sources', 'https://github.com/CocoaPods/Specs.git').split(',')
          @private         = argv.flag?('private', false)
          @swift_version   = argv.option('swift-version', nil)
          @podspecs_paths  = argv.arguments!
          super
        end

        def validate!
          super
        end

        def run
          UI.puts
          podspecs_to_lint.each do |podspec|
            validator                = Validator.new(podspec, @source_urls)
            validator.local          = true
            validator.quick          = @quick
            validator.no_clean       = !@clean
            validator.fail_fast      = @fail_fast
            validator.allow_warnings = @allow_warnings
            validator.no_subspecs    = !@subspecs || @only_subspec
            validator.only_subspec   = @only_subspec
            validator.use_frameworks = @use_frameworks
            validator.ignore_public_only_results = @private
            validator.swift_version = @swift_version
            validator.validate

            unless @clean
              UI.puts "Pods workspace available at `#{validator.validation_dir}/App.xcworkspace` for inspection."
              UI.puts
            end
            if validator.validated?
              UI.puts "#{validator.spec.name} passed validation.".green
            else
              spec_name = podspec
              spec_name = validator.spec.name if validator.spec
              message = "#{spec_name} did not pass validation, due to #{validator.failure_reason}."

              if @clean
                message << "\nYou can use the `--no-clean` option to inspect " \
                  'any issue.'
              end
              raise Informative, message
            end
          end
        end

        private

        #----------------------------------------#

        # !@group Private helpers

        # @return [Pathname] The path of the podspec found in the current
        #         working directory.
        #
        # @raise  If no podspec is found.
        # @raise  If multiple podspecs are found.
        #
        def podspecs_to_lint
          if !@podspecs_paths.empty?
            Array(@podspecs_paths)
          else
            podspecs = Pathname.glob(Pathname.pwd + '*.podspec{.json,}')
            if podspecs.count.zero?
              raise Informative, 'Unable to find a podspec in the working ' \
                'directory'
            end
            podspecs
          end
        end
      end
    end
  end
end
