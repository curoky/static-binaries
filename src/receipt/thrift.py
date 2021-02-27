#!/usr/bin/env python3

import os
import sys
import logging
from packaging import version
from dataclasses import dataclass
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from generator import FormulaGenerator, ActionGenerator, ActionContext, FormulaContext


@dataclass(init=True)
class FContext(FormulaContext):

    def __post_init__(self):
        super().__post_init__()
        self.with_cmake = True
        if version.parse(self.version) <= version.parse('0.9.2'):
            self.with_cmake = False
            self.with_autotools = True
        if version.parse(self.version) <= version.parse('0.9.1'):
            self.test_retcode = 1
            self.gcc_version = '4.9'


def main():
    fg = FormulaGenerator()
    ctxs = [
        # FContext(version='0.2.0', test_version='20080411-exported'),
        FContext(version='0.8.0'),
        FContext(version='0.9.0'),
        FContext(version='0.9.1'),
        FContext(version='0.9.2'),
        FContext(version='0.9.3.0', tag="0.9.3"),
        FContext(version='0.9.3.1', test_version='0.9.3'),
        FContext(version='0.10.0'),
        FContext(version='0.11.0'),
        FContext(version='0.12.0'),
        FContext(version='0.13.0'),
    ]
    for ctx in ctxs:
        fg.generate(filename=f'thrift@{ctx.version}', template_name='thrift.rb', ctx=ctx)

    ag = ActionGenerator()
    ag.generate(filename='thrift',
                ctx=ActionContext(name='thrift',
                                  versions=[fc.version for fc in ctxs],
                                  bins=['thrift']))
    return 0


if __name__ == "__main__":
    # logging.basicConfig(level=logging.DEBUG)
    logging.basicConfig(level=logging.INFO)
    sys.exit(main())
