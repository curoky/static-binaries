#!/usr/bin/env python3

import os
import sys
import logging
from packaging import version
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from generator import FormulaGenerator, ActionGenerator, ActionContext, FormulaContext
from dataclasses import dataclass


@dataclass(init=True)
class FContext(FormulaContext):
    pass

def main():
    fg = FormulaGenerator()
    ctxs = [
        FContext(version='5.2.5'),
        FContext(version='5.2.4'),
        FContext(version='5.2.3'),
        FContext(version='5.2.2'),
        FContext(version='5.2.1'),
        FContext(version='5.2.0'),
        FContext(version='5.0.8'),
        FContext(version='5.0.7'),
        FContext(version='5.0.6'),
        FContext(version='5.0.5'),
        FContext(version='5.0.4'),
        FContext(version='5.0.3'),
        FContext(version='5.0.2'),
        FContext(version='5.0.1'),
        FContext(version='5.0.0'),
    ]

    for ctx in ctxs:
        fg.generate(filename=f'xz@{ctx.version}', template_name='xz.rb', ctx=ctx)

    ag = ActionGenerator()
    ag.generate(filename='xz',
                ctx=ActionContext(name='xz', versions=[fc.version for fc in ctxs], bins=['xz']))
    return 0


if __name__ == "__main__":
    # logging.basicConfig(level=logging.DEBUG)
    logging.basicConfig(level=logging.INFO)
    sys.exit(main())
