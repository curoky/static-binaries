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

    def __post_init__(self):
        super().__post_init__()

        if version.parse('3.7.1') <= version.parse(self.tag) <= version.parse('3.8.0'):
            self.need_patch = True
            self.patch_file = '3.7.patch'
        if version.parse('3.9.2') <= version.parse(self.tag):
            self.need_patch = True
            self.patch_file = '3.9.patch'


def main():
    fg = FormulaGenerator()
    ctxs = [
        FContext(version='3.1', tag='v3.1.0'),
        FContext(version='3.2', tag='v3.2.1', test_version='3.2.0'),
        FContext(version='3.3', tag='v3.3.2'),
        FContext(version='3.4', tag='v3.4.1', test_version='3.4.0'),
        FContext(version='3.5', tag='v3.5.2', test_version='3.5.1'),
        # FContext(version='3.6', tag='v3.6.1'),
        FContext(version='3.7', tag='v3.7.1'),
        FContext(version='3.8', tag='v3.8.0'),
        FContext(version='3.9', tag='v3.9.2'),
        FContext(version='3.13', tag='v3.13.0.1', test_version='3.13.0'),
        FContext(version='3.14', tag='v3.14.0', test_version='3.14.0'),
        FContext(version='4.0', tag='v4.0.0-rc2', test_version='4.0.0'),
    ]

    for ctx in ctxs:
        fg.generate(filename=f'protoc@{ctx.version}', template_name='protoc.rb', ctx=ctx)

    ag = ActionGenerator()
    ag.generate(filename='protoc',
                ctx=ActionContext(name='protoc',
                                  versions=[fc.version for fc in ctxs],
                                  bins=['protoc']))
    return 0


if __name__ == "__main__":
    # logging.basicConfig(level=logging.DEBUG)
    logging.basicConfig(level=logging.INFO)
    sys.exit(main())
