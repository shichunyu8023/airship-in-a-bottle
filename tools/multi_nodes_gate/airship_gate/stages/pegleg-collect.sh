#!/usr/bin/env bash
# Copyright 2018 AT&T Intellectual Property.  All other rights reserved.
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

set -xe

source "${GATE_UTILS}"

mkdir -p "${DEFINITION_DEPOT}"
chmod 777 "${DEFINITION_DEPOT}"

render_pegleg_cli() {
    cli_string="pegleg -v site"

    if [[ "${GERRIT_SSH_USER}" ]]
    then
      cli_string+=" -u ${GERRIT_SSH_USER}"
    fi

    if [[ "${GERRIT_SSH_KEY}" ]]
    then
      cli_string+=" -k /workspace/${GERRIT_SSH_KEY}"
    fi

    primary_repo=$(config_pegleg_primary_repo)

    if [[ -d "${REPO_ROOT}/${primary_repo}" ]]
    then
      # NOTE: to get latest pegleg colllect to work
      # airship-in-bottle repo has versions (v1.0demo, v1.0dev) within global
      # and that is preventing pegleg to collect documents.
      # It complains with duplicate data
      $(find ${REPO_ROOT}/${primary_repo}  -name "v1.0dev" -type d \
        -exec rm -r {} +)
      cli_string="${cli_string} -r /workspace/${primary_repo}"
    else
      log "${primary_repo} not a valid primary repository"
      return 1
    fi

    aux_repos=($(config_pegleg_aux_repos))

    if [[ ${#aux_repos[@]} -gt 0 ]]
    then
        for r in ${aux_repos[*]}
        do
          cli_string="${cli_string} -e ${r}=/workspace/${r}"
        done
    fi

    cli_string="${cli_string} collect -s /collect"

    cli_string="${cli_string} $(config_pegleg_sitename)"

    echo ${cli_string}
}

collect_design_docs() {
  docker run \
    --rm -t \
    --network host \
    -v "${REPO_ROOT}":/workspace \
    -v "${DEFINITION_DEPOT}":/collect \
    "${IMAGE_PEGLEG_CLI}" \
    $(render_pegleg_cli)
}

collect_initial_docs() {
  collect_design_docs
  log "Generating virtmgr key documents"
  gen_libvirt_key && install_libvirt_key
  collect_ssh_key
}

log "Collecting site definition to ${DEFINITION_DEPOT}"

if [[ "$1" != "update" ]];
then
  collect_initial_docs
else
  collect_design_docs
fi
