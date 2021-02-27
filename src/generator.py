import os
import sys
import jinja2
import codecs
import logging
from typing import List
from dataclasses import dataclass


@dataclass(init=True)
class FormulaContext:
    version: str
    tag: str = ""
    sha: str = ""

    need_patch: bool = False
    patch_file: str = ""
    patch_sha: str = ""

    gcc_version: str = "10"

    test_version: str = ""
    test_retcode: int = 0

    file_version: str = ""
    class_version: str = ""

    with_autotools: bool = False
    with_cmake: bool = False

    def __post_init__(self):
        if not self.tag:
            self.tag = self.version
        if self.patch_file:
            self.need_patch = True
        if not self.file_version:
            self.file_version = self.version
        if not self.test_version:
            self.test_version = self.tag.removeprefix('v')
        if not self.class_version:
            self.class_version = self.file_version.upper().replace('.', '')



class FormulaGenerator(object):

    def __init__(self) -> None:
        templates_folder = os.path.abspath(os.path.join(os.path.dirname(__file__), "templates"))

        self.env = jinja2.Environment(
            trim_blocks=True,
            lstrip_blocks=True,
            loader=jinja2.FileSystemLoader(templates_folder),
        )

        self.output_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../Formula"))

    def write_output(self, filename, content):
        with codecs.open(os.path.join(self.output_dir, filename), 'w', 'utf8') as f:
            f.write(content)

    def generate(self, filename, template_name, ctx):
        template = self.env.get_template(template_name + '.j2')
        self.write_output(filename + '.rb', template.render(ctx=ctx))


@dataclass(init=True)
class ActionContext:
    name: str
    versions: List[str]
    bins: List[str]


class ActionGenerator(object):

    def __init__(self) -> None:
        templates_folder = os.path.abspath(os.path.join(os.path.dirname(__file__), "templates"))

        self.env = jinja2.Environment(
            trim_blocks=True,
            lstrip_blocks=True,
            loader=jinja2.FileSystemLoader(templates_folder),
        )

        self.output_dir = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../.github/workflows"))

    def write_output(self, filename, content):
        with codecs.open(os.path.join(self.output_dir, filename), 'w', 'utf8') as f:
            f.write(content)

    def generate(self, filename, ctx):
        template = self.env.get_template('action.yaml.j2')
        self.write_output(f'build-{filename}.yaml', template.render(ctx=ctx))
