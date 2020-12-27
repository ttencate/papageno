def cached(func):
    '''
    Decorator for class properties that makes them lazily evaluated at most
    once. Use after `@property` decorator.
    '''
    attr_name = '__cached__' + func.__name__
    def cached_func(self):
        value = getattr(self, attr_name, None)
        if value is None:
            value = func(self)
            setattr(self, attr_name, value)
        return value
    return cached_func
