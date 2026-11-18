#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p build/test-modules
/usr/bin/xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path build/test-modules \
  PlannerModel.swift ScheduleModel.swift ModelChecks.swift -o build/model-checks
build/model-checks
/usr/bin/xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path build/test-modules \
  PlannerModel.swift ScheduleModel.swift PlannerStore.swift StoreChecks.swift -o build/store-checks
build/store-checks
