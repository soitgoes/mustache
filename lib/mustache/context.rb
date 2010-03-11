class Mustache
  # A ContextMiss is raised whenever a tag's target can not be found
  # in the current context if `Mustache#raise_on_context_miss?` is
  # set to true.
  #
  # For example, if your View class does not respond to `music` but
  # your template contains a `{{music}}` tag this exception will be raised.
  #
  # By default it is not raised. See Mustache.raise_on_context_miss.
  class ContextMiss < RuntimeError;  end

  # A Context represents the context which a Mustache template is
  # executed within. All Mustache tags reference keys in the Context.
  class Context
    # Expect to be passed an instance of `Mustache`.
    def initialize(mustache)
      @mustache = mustache
      @stack = [@mustache]
    end

    # A {{>partial}} tag translates into a call to the context's
    # `partial` method, which would be this sucker right here.
    #
    # If the Mustache view handling the rendering (e.g. the view
    # representing your profile page or some other template) responds
    # to `partial`, we call it and use the result. Otherwise we render
    # and compile the partial as its own view and return the result.
    def partial(name)
      if @mustache.respond_to? :partial
        @mustache.partial(name)
      else
        @mustache.class.render_file(name, self)
      end
    end

    # Adds a new object to the context's internal stack.
    #
    # Returns the Context.
    def push(new)
      @stack.unshift(new)
      self
    end
    alias_method :update, :push

    # Removes the most recently added object from the context's
    # internal stack.
    #
    # Returns the Context.
    def pop
      @stack.shift
      self
    end

    # Can be used to add a value to the context in a hash-like way.
    #
    # context[:name] = "Chris"
    def []=(name, value)
      push(name => value)
    end

    # Alias for `fetch`.
    def [](name)
      fetch(name, nil)
    end

    # Do we know about a particular key? In other words, will calling
    # `context[key]` give us a result that was set. Basically.
    def has_key?(key)
      !!fetch(key)
    rescue ContextMiss
      false
    end

    # Similar to Hash#fetch, finds a value by `name` in the context's
    # stack. You may specify the default return value by passing a
    # second parameter.
    #
    # If no second parameter is passed (or raise_on_context_miss is
    # set to true), will raise a ContextMiss exception on miss.
    def fetch(name, default = :__raise)
      @stack.each do |frame|
        hash = frame.respond_to?(:has_key?)

        if hash && frame.has_key?(name)
          return frame[name]
        elsif hash && frame.has_key?(name.to_s)
          return frame[name.to_s]
        elsif !hash && frame.respond_to?(name)
          return frame.__send__(name)
        end
      end

      if default == :__raise || @mustache.raise_on_context_miss?
        raise ContextMiss.new("Can't find #{name} in #{@stack.inspect}")
      else
        default
      end
    end
  end
end
