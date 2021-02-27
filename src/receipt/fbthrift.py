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
        # FContext(version='2018.06.04'),
        # FContext(version='2018.12.31'),
        FContext(version='2019.06.03'),
        FContext(version='2019.12.30'),
    ]

    for ctx in ctxs:
        fg.generate(filename=f'fbthrift@{ctx.version}', template_name='fbthrift.rb', ctx=ctx)

    ag = ActionGenerator()
    ag.generate(filename='fbthrift',
                ctx=ActionContext(name='fbthrift',
                                  versions=[fc.version for fc in ctxs],
                                  bins=['thrift1']))
    return 0


if __name__ == "__main__":
    # logging.basicConfig(level=logging.DEBUG)
    logging.basicConfig(level=logging.INFO)
    sys.exit(main())
