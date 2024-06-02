# Copyright 2018-present MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


import sys
from collections import OrderedDict as OD
from typing import Any, Iterable, Mapping, MutableMapping, MutableSequence, Sequence, Union

Scalar = Union[str, bool, int, None, float]
"YAML simple schema scalar types"
ValueSequence = Sequence["Value"]
"Sequence of YAML simple values"
MutableValueArray = MutableSequence["Value"]
"A mutable sequence of JSON values"
ValueMapping = Mapping[Scalar, "Value"]
"A YAML mapping type (arbitrary scalars as keys)"
MutableValueMapping = MutableMapping[Scalar, "Value"]
"A mutable YAML mapping type"
Value = Union[ValueSequence, ValueMapping, Scalar]
"Any YAML simple value"
MutableValue = Union[MutableValueMapping, MutableValueArray, Scalar]
"Any YAML simple value, which may be a mutable sequence or map"

ValueOrderedDict = OD[Scalar, Value]
"An OrderedDict of YAML values"


try:
    import yaml
    import yamlordereddictloader  # type: ignore
except ImportError:
    sys.stderr.write("try 'pip install -r evergreen_config_generator/requirements.txt'\n")
    raise


class ConfigObject(object):
    @property
    def name(self) -> str:
        return "UNSET"

    def to_dict(self) -> Value:
        return OD([("name", self.name)])


# We want legible YAML tasks:
#
#     - name: debug-compile
#       tags: [zlib, snappy, compression, openssl]
#       commands:
#       - command: shell.exec
#         params:
#           script: |-
#             set -o errexit
#             ...
#
# Write values compactly except multiline strings, which use "|" style. Write
# tag sets as lists.


class _Dumper(yamlordereddictloader.Dumper):
    def __init__(self, *args: Value, **kwargs: Value):
        super().__init__(*args, **kwargs)  # type: ignore
        self.add_representer(set, type(self).represent_set)
        # Use "multi_representer" to represent all subclasses of ConfigObject.
        self.add_multi_representer(ConfigObject, type(self).represent_config_object)

    def represent_scalar(self, tag: str, value: Value, style: str | None = None) -> yaml.ScalarNode:
        if isinstance(value, (str)) and "\n" in value:
            style = "|"
        return super().represent_scalar(tag, value, style)  # type: ignore

    def represent_set(self, data: Iterable[Value]) -> yaml.MappingNode:
        return super().represent_list(sorted(set(data)))  # type: ignore

    def represent_config_object(self, obj: ConfigObject) -> yaml.Node:
        d = obj.to_dict()
        return super().represent_data(d)  # type: ignore


def yaml_dump(obj: Any):
    return yaml.dump(obj, Dumper=_Dumper, default_flow_style=False)


def generate(config: Any, path: str):
    """Dump config to a file as YAML.
    config is a dict, preferably an OrderedDict. path is a file path.
    """
    f = open(path, "w+")
    f.write(
        """####################################
# Evergreen configuration
#
# Generated with evergreen_config_generator from
# github.com/mongodb-labs/drivers-evergreen-tools
#
# DO NOT EDIT THIS FILE
#
####################################
"""
    )
    f.write(yaml_dump(config))
