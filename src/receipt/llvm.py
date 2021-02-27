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
    extra_resource: bool = False
    use_old_registry: bool = False

    def __post_init__(self):
        super().__post_init__()
        if self.tag == '8.0.1':
            self.gcc_version = '9'
        if version.parse('3.9.2') <= version.parse(self.tag):
            self.patch_file = '3.9.patch'
        if version.parse(self.tag) <= version.parse('8.0.1'):
            self.extra_resource = True
        if version.parse(self.tag) <= version.parse('6.0.1'):
            self.use_old_registry = True


def main():
    fg = FormulaGenerator()
    ctxs = [
        FContext(version='3', tag='3.9.1'),
        FContext(version='4', tag='4.0.1'),
        FContext(version='5', tag='5.0.2'),
        FContext(version='6', tag='6.0.1'),
        FContext(version='7', tag='7.1.0'),
        FContext(version='8', tag='8.0.1'),
        FContext(version='9', tag='9.0.1'),
        FContext(version='10', tag='10.0.1'),
        FContext(version='11', tag='11.0.0'),
    ]

    for ctx in ctxs:
        fg.generate(filename=f'llvm@{ctx.version}', template_name='llvm.rb', ctx=ctx)

    ag = ActionGenerator()
    ag.generate(filename='llvm',
                ctx=ActionContext(name='llvm',
                                  versions=[fc.version for fc in ctxs],
                                  bins=['clang-format', 'clang-query', 'clang-tidy']))
    return 0


if __name__ == "__main__":
    # logging.basicConfig(level=logging.DEBUG)
    logging.basicConfig(level=logging.INFO)
    sys.exit(main())
