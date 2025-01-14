module Trailblazer
  module Macro

    def self.Model(model_class = nil, action = :new, find_by_key = :id, id: 'model.build', not_found_terminus: false)
      task = Activity::TaskBuilder::Binary(Model.new)

      injections = {
        Activity::Railway.Inject() => [:params], # pass-through {:params} if it's in ctx.

        # defaulting as per Inject() API.
        Activity::Railway.Inject() => {
          :"model.class"          => ->(*) { model_class },
          :"model.action"         => ->(*) { action },
          :"model.find_by_key"    => ->(*) { find_by_key },
        }
      }

      options = {task: task, id: id}.merge(injections)

      options = options.merge(Activity::Railway.Output(:failure) => Activity::Railway.End(:not_found)) if not_found_terminus

      options
    end

    class Model
      def call(ctx, params: {}, **)
        builder                 = Model::Builder.new
        ctx[:model]         = model = builder.call(ctx, params)
        ctx[:"result.model"] = result = Operation::Result.new(!model.nil?, {})

        result.success?
      end

      class Builder
        def call(ctx, params)
          action        = ctx[:"model.action"]
          model_class   = ctx[:"model.class"]
          find_by_key   = ctx[:"model.find_by_key"]
          action        = :pass_through unless %i[new find_by].include?(action)

          send("#{action}!", model_class, params, ctx[:"model.action"], find_by_key)
        end

        def new!(model_class, params, *)
          model_class.new
        end

        # Doesn't throw an exception and will return false to divert to Left.
        def find_by!(model_class, params, action, find_by_key, *)
          model_class.find_by(find_by_key.to_sym => params[find_by_key])
        end

        # Call any method on the model class and pass find_by_key, for example find(params[:id]).
        def pass_through!(model_class, params, action, find_by_key, *)
          model_class.send(action, params[find_by_key])
        end
      end
    end
  end # Macro
end
