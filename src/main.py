#!/usr/bin/env python3
import sys
import logging
from generator import Generator, FormulaContext
from dataclasses import dataclass
from packaging import version


@dataclass(init=True)
class LlvmContext(FormulaContext):
    extra_resource: bool = False
    use_old_registry: bool = False

    def __post_init__(self):
        super().__post_init__()
        if version.parse(self.tag) <= version.parse('8.0.1'):
            self.extra_resource = True
        if version.parse(self.tag) <= version.parse('6.0.1'):
            self.use_old_registry = True


@dataclass(init=True)
class ThriftContext(FormulaContext):

    def __post_init__(self):
        super().__post_init__()
        self.with_cmake = True
        if version.parse(self.version) <= version.parse('0.9.2'):
            self.with_cmake = False
            self.with_autotools = True
        if version.parse(self.version) <= version.parse('0.9.1'):
            self.test_retcode = 1


def main():
    g = Generator(name='fbthrift',
                  bins=['thrift1'],
                  fctxs=[
                      FormulaContext(version='2019.06.03'),
                      FormulaContext(version='2019.12.30'),
                      FormulaContext(version='2020.12.14'),
                      FormulaContext(version='2021.03.01'),
                  ])
    g.generate()

    g = Generator(name='llvm',
                  bins=['clang-format', 'clang-query', 'clang-tidy'],
                  fctxs=[
                      LlvmContext(version='3.9.1'),
                      LlvmContext(version='4.0.1'),
                      LlvmContext(version='5.0.2'),
                      LlvmContext(version='6.0.1'),
                      LlvmContext(version='7.1.0'),
                      LlvmContext(version='8.0.1'),
                      LlvmContext(version='9.0.1'),
                      LlvmContext(version='10.0.1'),
                      LlvmContext(version='11.0.0')
                  ])
    g.generate()

    g = Generator(
        name='protoc',
        bins=['protoc'],
        fctxs=[
            FormulaContext(version='3.1.0'),
            FormulaContext(version='3.2.1', test_version='3.2.0'),
            FormulaContext(version='3.3.2'),
            FormulaContext(version='3.4.1', test_version='3.4.0'),
            FormulaContext(version='3.5.2', test_version='3.5.1'),
            # FormulaContext(version='3.6'),
            FormulaContext(version='3.7.1'),
            FormulaContext(version='3.8.0'),
            FormulaContext(version='3.9.2'),
            FormulaContext(version='3.13.0.1', test_version='3.13.0'),
            FormulaContext(version='3.14.0', test_version='3.14.0'),
            FormulaContext(version='3.15.6', test_version='3.15.6'),
        ])
    g.generate()

    g = Generator(
        name='thrift',
        bins=['thrift'],
        fctxs=[
            # ThriftContext(version='0.2.0', test_version='20080411-exported'),
            ThriftContext(version='0.8.0'),
            ThriftContext(version='0.9.0'),
            ThriftContext(version='0.9.1'),
            ThriftContext(version='0.9.2'),
            ThriftContext(version='0.9.3'),
            ThriftContext(version='0.9.3.1', test_version='0.9.3'),
            ThriftContext(version='0.10.0'),
            ThriftContext(version='0.11.0'),
            ThriftContext(version='0.12.0'),
            ThriftContext(version='0.13.0'),
            ThriftContext(version='0.14.1'),
        ])
    g.generate()

    g = Generator(name='xz',
                  bins=['xz'],
                  fctxs=[
                      FormulaContext(version='5.2.5'),
                      FormulaContext(version='5.2.4'),
                      FormulaContext(version='5.2.3'),
                      FormulaContext(version='5.2.2'),
                      FormulaContext(version='5.2.1'),
                      FormulaContext(version='5.2.0'),
                      FormulaContext(version='5.0.8'),
                      FormulaContext(version='5.0.7'),
                      FormulaContext(version='5.0.6'),
                      FormulaContext(version='5.0.5'),
                      FormulaContext(version='5.0.4'),
                      FormulaContext(version='5.0.3'),
                      FormulaContext(version='5.0.2'),
                      FormulaContext(version='5.0.1'),
                      FormulaContext(version='5.0.0'),
                  ])
    g.generate()

    g = Generator(name='tmux',
                  bins=['tmux'],
                  fctxs=[
                      FormulaContext(version='3.1', tag='3.1c'),
                      FormulaContext(version='3.0', tag='3.0a'),
                      FormulaContext(version='2.9', tag='2.9a'),
                      FormulaContext(version='2.8'),
                      FormulaContext(version='2.7'),
                      FormulaContext(version='2.6'),
                      FormulaContext(version='2.5'),
                  ])
    g.generate()
    # g = Generator(name='python3', bins=[], fctxs=[])
    # g.generate()

    return 0


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    sys.exit(main())
