#!/usr/bin/env python3
# Copyright 2021 curoky(cccuroky@gmail.com).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import shutil
from pathlib import Path
from typing import List

import typer

app = typer.Typer(name='pack', help='Pack files')


@app.command()
def pack(path: Path, out: Path, files: List[str]):
    typer.secho('start copying', fg='green')
    os.makedirs(out, exist_ok=True)
    for file in files:
        search_file_name = file
        target_file_name = file
        if ':' in file:
            search_file_name, target_file_name = file.split(':')
        for p in path.glob(f'**/{search_file_name}'):
            version = p.as_posix().split('/')[1]
            new_path = out / f'{target_file_name}-{version}'
            typer.secho(f'{p} => {new_path}', fg='blue')
            shutil.copy(p, new_path)


if __name__ == '__main__':
    app()
