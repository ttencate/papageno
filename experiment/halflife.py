import ebisu

import random

def days(minutes=0.0, seconds=0.0):
    return minutes / (60*24) + seconds / (60*60*24)

class Simple:
    '''
    Simpler model: each time you get it right or wrong, multiply halflife by a
    fixed factor. API-compatible with the ebisu module.
    '''
    FAILURE_FACTOR = 1 / 2.0
    MIN_HALFLIFE = days(minutes=1.0)
    MAX_HALFLIFE = 365
    def __init__(self, success_factor, failure_factor):
        self.success_factor = success_factor
        self.failure_factor = failure_factor
    def defaultModel(self, halflife):
        return halflife
    def predictRecall(self, halflife, tnow, exact=True):
        return 0.5**(tnow / halflife)
    def updateRecall(self, halflife, successes, total, tnow):
        failures = total - successes
        halflife = halflife * self.success_factor**successes * self.failure_factor**failures
        return min(Simple.MAX_HALFLIFE, max(Simple.MIN_HALFLIFE, halflife))
    def modelToPercentileDecay(self, halflife, percentile=0.5):
        assert(percentile == 0.5)
        return halflife
    def __str__(self):
        return f'Simple({self.success_factor:.3f}, {self.failure_factor:.3f})'

r = random.Random(42)

LEARNING_RATE = 0.0

class Knowledge:
    INITIAL_HALFLIFE = days(minutes=1.0)
    def __init__(self, model, ease, now):
        self.ease = ease
        self.model = model
        self.prior = None
        self.last_time = now
    def ask(self):
        return r.uniform(0.0, 1.0) <= self.ease
    def recall(self, now):
        if self.prior is None:
            return 0.0
        else:
            return self.model.predictRecall(self.prior, now - self.last_time, exact=True)
    def update(self, correct, now):
        if self.prior is None:
            self.prior = model.defaultModel(Knowledge.INITIAL_HALFLIFE)
        else:
            self.prior = self.model.updateRecall(self.prior, 1 if correct else 0, 1, now - self.last_time)
        self.last_time = now
        self.ease = 1 - ((1 - self.ease) * (1 - LEARNING_RATE))
    def halflife(self):
        if self.prior is None:
            return 0.0
        else:
            return self.model.modelToPercentileDecay(self.prior, percentile=0.5)

models = [ebisu, Simple(1.5, 1/1.5**2), Simple(1.3, 1/1.3**2), Simple(1.2, 1/1.2**2)]
knowledgess = [
    [Knowledge(model, ease, -1) for ease in (1, 1, 1, 1, 1, 1, 0.9, 0.8, 0.8, 0.3)]
    for model in models
]
index = 9
print(f'day  {"  ".join(map(str, models))}')
for day in range(14):
    totals = []
    news = []
    askeds = []
    succs = []
    for (model, knowledges) in zip(models, knowledgess):
        now = day
        if day > 0:
            knowledges += [Knowledge(model, ease, now - 1) for ease in (1.0, 1.0, 0.9, 0.9, 0.8, 0.8, 0.7, 0.7, 0.6, 0.6)]
        total = 0
        new = 0
        asked = 0
        succ = 0
        for i in range(100):
            now += days(seconds=10.0)
            knowledge = min(*knowledges, key=lambda k: k.recall(now))
            i = knowledges.index(knowledge)
            #print(knowledge.recall(now, exact=True), knowledge.prior)
            #if i >= 40 and knowledge.recall(now) > 0.8:
            #    break
            correct = knowledge.ask()
            total += 1
            if i >= len(knowledges) - 10:
                new += 1
            if index < len(knowledges) and knowledge == knowledges[index]:
                asked += 1
                if correct:
                    succ += 1
            knowledge.update(correct, now)
        totals.append(total)
        news.append(new)
        askeds.append(asked)
        succs.append(succ)

    print(f'{day:3}', end='')
    if index < len(knowledgess[0]):
        for (model, knowledges, asked, succ, new, total) in zip(models, knowledgess, askeds, succs, news, totals):
            print(f'  {succ:2}/{asked:2}/{new:2}/{total:2}  {knowledges[index].halflife():5.03f}', end='')
    print()
