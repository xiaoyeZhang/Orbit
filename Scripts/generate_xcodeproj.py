#!/usr/bin/env python3
"""
为 Orbit 生成 Xcode 工程（.xcodeproj/project.pbxproj）。

- 离线、纯标准库，无需 xcodegen / tuist。
- 自动扫描 `Orbit/` 下所有 .swift（编译）、Assets.xcassets（资源）、Info.plist（仅引用）。
- 以后新增 / 删除文件后，重新运行本脚本即可：python3 Scripts/generate_xcodeproj.py
"""
import os, hashlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
APP_NAME = "Orbit"
SRC_DIR = "Orbit"                      # 源码根目录（相对工程根）
BUNDLE_ID = "com.example.jagat"
DEPLOYMENT_TARGET = "16.0"
INFO_PLIST = "Orbit/Resources/Info.plist"

PROJ_DIR = os.path.join(ROOT, f"{APP_NAME}.xcodeproj")


def oid(key: str) -> str:
    """由 key 生成稳定的 24 位十六进制对象 ID。"""
    return hashlib.md5(key.encode()).hexdigest().upper()[:24]


# ---- 扫描文件系统，构建分组树 ----
class Node:
    def __init__(self, name, path, is_dir):
        self.name = name
        self.path = path          # 相对工程根的路径
        self.is_dir = is_dir
        self.children = []


def scan(rel_path) -> Node:
    abs_path = os.path.join(ROOT, rel_path)
    name = os.path.basename(rel_path)
    node = Node(name, rel_path, True)
    for entry in sorted(os.listdir(abs_path)):
        if entry.startswith("."):
            continue
        child_rel = os.path.join(rel_path, entry)
        child_abs = os.path.join(ROOT, child_rel)
        if os.path.isdir(child_abs):
            if entry.endswith(".xcassets"):
                node.children.append(Node(entry, child_rel, False))   # 资源目录当作叶子
            else:
                node.children.append(scan(child_rel))
        else:
            node.children.append(Node(entry, child_rel, False))
    return node


def classify(name):
    if name.endswith(".swift"):
        return "source"
    if name.endswith(".xcassets"):
        return "asset"
    if name == "Info.plist":
        return "plist"          # 应用 Info.plist：仅作引用，由 INFOPLIST_FILE 构建设置使用
    if name.endswith(".plist"):
        return "resource"       # 其他 plist（如 GoogleService-Info.plist）：需拷入 App bundle
    return "other"


FILE_TYPES = {
    "source": "sourcecode.swift",
    "asset": "folder.assetcatalog",
    "plist": "text.plist.xml",
    "resource": "text.plist.xml",
    "other": "text",
}

# 收集对象
sources = []   # (fileref_id, buildfile_id, name, path)
assets = []
plists = []
file_refs = {}  # path -> (id, name, filetype)
groups = []     # (id, name, children_ids, path_segment)


def add_file(node):
    kind = classify(node.name)
    fid = oid("fileref:" + node.path)
    file_refs[node.path] = (fid, node.name, FILE_TYPES[kind])
    if kind == "source":
        bid = oid("buildfile:" + node.path)
        sources.append((fid, bid, node.name, node.path))
    elif kind in ("asset", "resource"):
        bid = oid("buildfile:" + node.path)
        assets.append((fid, bid, node.name, node.path))
    elif kind == "plist":
        plists.append((fid, node.name, node.path))
    return fid


def build_groups(node) -> str:
    """递归创建分组，返回该分组的 id。"""
    child_ids = []
    for c in node.children:
        if c.is_dir:
            child_ids.append(build_groups(c))
        else:
            child_ids.append(add_file(c))
    gid = oid("group:" + node.path)
    # 根分组用 name=Orbit、path=Orbit；子分组 path 用相对父级的最后一段
    groups.append((gid, node.name, child_ids, node.name))
    return gid


tree = scan(SRC_DIR)
src_group_id = build_groups(tree)

# 固定对象 ID
PROJECT_ID = oid("project")
MAIN_GROUP_ID = oid("maingroup")
PRODUCTS_GROUP_ID = oid("productsgroup")
TARGET_ID = oid("target")
PRODUCT_REF_ID = oid("product.app")
SOURCES_PHASE_ID = oid("phase.sources")
FRAMEWORKS_PHASE_ID = oid("phase.frameworks")
RESOURCES_PHASE_ID = oid("phase.resources")
PROJ_CONFLIST_ID = oid("conflist.project")
TGT_CONFLIST_ID = oid("conflist.target")
PROJ_DEBUG_ID = oid("config.project.debug")
PROJ_RELEASE_ID = oid("config.project.release")
TGT_DEBUG_ID = oid("config.target.debug")
TGT_RELEASE_ID = oid("config.target.release")

# Firebase（可选）：ENABLE_FIREBASE=1 时注入 firebase-ios-sdk 的 SwiftPM 依赖
ENABLE_FIREBASE = os.environ.get("ENABLE_FIREBASE") == "1"
FB_PKGREF_ID = oid("pkgref.firebase")
FB_PRODUCTS = ["FirebaseAuth", "FirebaseFirestore"]
FB_PRODDEP = {p: oid("proddep." + p) for p in FB_PRODUCTS}
FB_BUILDFILE = {p: oid("pkgbuildfile." + p) for p in FB_PRODUCTS}


def fmt_settings(d):
    lines = []
    for k in sorted(d.keys()):
        v = d[k]
        if isinstance(v, list):
            inner = "".join(f"\t\t\t\t\t{item},\n" for item in v)
            lines.append(f"\t\t\t\t{k} = (\n{inner}\t\t\t\t);")
        else:
            lines.append(f"\t\t\t\t{k} = {v};")
    return "\n".join(lines)


PROJ_DEBUG = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu11",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ['"DEBUG=1"', '"$(inherited)"'],
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "MTL_FAST_MATH": "YES",
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
}
PROJ_RELEASE = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_NS_ASSERTIONS": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu11",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "MTL_FAST_MATH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
    "VALIDATE_PRODUCT": "YES",
}
TGT_COMMON = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": INFO_PLIST,
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "LD_RUNPATH_SEARCH_PATHS": ['"$(inherited)"', '"@executable_path/Frameworks"'],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}


def merge(a, b):
    d = dict(a)
    d.update(b)
    return d


TGT_DEBUG = merge(TGT_COMMON, {"SWIFT_OPTIMIZATION_LEVEL": '"-Onone"'})
TGT_RELEASE = merge(TGT_COMMON, {"SWIFT_COMPILATION_MODE": "wholemodule"})
if ENABLE_FIREBASE:
    # 定义 JAGAT_FIREBASE 编译标志，激活 FirebaseBackendService（仅 Firebase 模式）
    _cond = '"$(inherited) JAGAT_FIREBASE"'
    TGT_DEBUG["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = _cond
    TGT_RELEASE["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = _cond


# ---- 拼装 pbxproj ----
out = []
out.append("// !$*UTF8*$!")
out.append("{")
out.append("\tarchiveVersion = 1;")
out.append("\tclasses = {")
out.append("\t};")
out.append("\tobjectVersion = 56;")
out.append("\tobjects = {")

# PBXBuildFile
out.append("\n/* Begin PBXBuildFile section */")
for fid, bid, name, path in sources:
    out.append(f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
for fid, bid, name, path in assets:
    out.append(f"\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
if ENABLE_FIREBASE:
    for p in FB_PRODUCTS:
        out.append(f"\t\t{FB_BUILDFILE[p]} /* {p} in Frameworks */ = {{isa = PBXBuildFile; productRef = {FB_PRODDEP[p]} /* {p} */; }};")
out.append("/* End PBXBuildFile section */")

# PBXFileReference
out.append("\n/* Begin PBXFileReference section */")
out.append(f"\t\t{PRODUCT_REF_ID} /* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for path, (fid, name, ftype) in sorted(file_refs.items()):
    out.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = \"{name}\"; sourceTree = \"<group>\"; }};")
out.append("/* End PBXFileReference section */")

# PBXFrameworksBuildPhase
out.append("\n/* Begin PBXFrameworksBuildPhase section */")
out.append(f"\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */ = {{")
out.append("\t\t\tisa = PBXFrameworksBuildPhase;")
out.append("\t\t\tbuildActionMask = 2147483647;")
out.append("\t\t\tfiles = (")
if ENABLE_FIREBASE:
    for p in FB_PRODUCTS:
        out.append(f"\t\t\t\t{FB_BUILDFILE[p]} /* {p} in Frameworks */,")
out.append("\t\t\t);")
out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
out.append("\t\t};")
out.append("/* End PBXFrameworksBuildPhase section */")

# PBXGroup
out.append("\n/* Begin PBXGroup section */")
# main group
out.append(f"\t\t{MAIN_GROUP_ID} = {{")
out.append("\t\t\tisa = PBXGroup;")
out.append("\t\t\tchildren = (")
out.append(f"\t\t\t\t{src_group_id} /* {APP_NAME} */,")
out.append(f"\t\t\t\t{PRODUCTS_GROUP_ID} /* Products */,")
out.append("\t\t\t);")
out.append("\t\t\tsourceTree = \"<group>\";")
out.append("\t\t};")
# products group
out.append(f"\t\t{PRODUCTS_GROUP_ID} /* Products */ = {{")
out.append("\t\t\tisa = PBXGroup;")
out.append("\t\t\tchildren = (")
out.append(f"\t\t\t\t{PRODUCT_REF_ID} /* {APP_NAME}.app */,")
out.append("\t\t\t);")
out.append("\t\t\tname = Products;")
out.append("\t\t\tsourceTree = \"<group>\";")
out.append("\t\t};")
# source groups
for gid, name, child_ids, seg in groups:
    out.append(f"\t\t{gid} /* {name} */ = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    for cid in child_ids:
        out.append(f"\t\t\t\t{cid},")
    out.append("\t\t\t);")
    out.append(f"\t\t\tpath = {seg};")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")
out.append("/* End PBXGroup section */")

# PBXNativeTarget
out.append("\n/* Begin PBXNativeTarget section */")
out.append(f"\t\t{TARGET_ID} /* {APP_NAME} */ = {{")
out.append("\t\t\tisa = PBXNativeTarget;")
out.append(f"\t\t\tbuildConfigurationList = {TGT_CONFLIST_ID} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */;")
out.append("\t\t\tbuildPhases = (")
out.append(f"\t\t\t\t{SOURCES_PHASE_ID} /* Sources */,")
out.append(f"\t\t\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */,")
out.append(f"\t\t\t\t{RESOURCES_PHASE_ID} /* Resources */,")
out.append("\t\t\t);")
out.append("\t\t\tbuildRules = (\n\t\t\t);")
out.append("\t\t\tdependencies = (\n\t\t\t);")
if ENABLE_FIREBASE:
    out.append("\t\t\tpackageProductDependencies = (")
    for p in FB_PRODUCTS:
        out.append(f"\t\t\t\t{FB_PRODDEP[p]} /* {p} */,")
    out.append("\t\t\t);")
out.append(f"\t\t\tname = {APP_NAME};")
out.append(f"\t\t\tproductName = {APP_NAME};")
out.append(f"\t\t\tproductReference = {PRODUCT_REF_ID} /* {APP_NAME}.app */;")
out.append("\t\t\tproductType = \"com.apple.product-type.application\";")
out.append("\t\t};")
out.append("/* End PBXNativeTarget section */")

# PBXProject
out.append("\n/* Begin PBXProject section */")
out.append(f"\t\t{PROJECT_ID} /* Project object */ = {{")
out.append("\t\t\tisa = PBXProject;")
out.append("\t\t\tattributes = {")
out.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
out.append("\t\t\t\tLastSwiftUpdateCheck = 1420;")
out.append("\t\t\t\tLastUpgradeCheck = 1420;")
out.append("\t\t\t\tTargetAttributes = {")
out.append(f"\t\t\t\t\t{TARGET_ID} = {{")
out.append("\t\t\t\t\t\tCreatedOnToolsVersion = 14.2;")
out.append("\t\t\t\t\t};")
out.append("\t\t\t\t};")
out.append("\t\t\t};")
out.append(f"\t\t\tbuildConfigurationList = {PROJ_CONFLIST_ID} /* Build configuration list for PBXProject \"{APP_NAME}\" */;")
out.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
out.append("\t\t\tdevelopmentRegion = en;")
out.append("\t\t\thasScannedForEncodings = 0;")
out.append("\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);")
out.append(f"\t\t\tmainGroup = {MAIN_GROUP_ID};")
out.append(f"\t\t\tproductRefGroup = {PRODUCTS_GROUP_ID} /* Products */;")
out.append("\t\t\tprojectDirPath = \"\";")
out.append("\t\t\tprojectRoot = \"\";")
if ENABLE_FIREBASE:
    out.append("\t\t\tpackageReferences = (")
    out.append(f"\t\t\t\t{FB_PKGREF_ID} /* XCRemoteSwiftPackageReference \"firebase-ios-sdk\" */,")
    out.append("\t\t\t);")
out.append("\t\t\ttargets = (")
out.append(f"\t\t\t\t{TARGET_ID} /* {APP_NAME} */,")
out.append("\t\t\t);")
out.append("\t\t};")
out.append("/* End PBXProject section */")

# PBXResourcesBuildPhase
out.append("\n/* Begin PBXResourcesBuildPhase section */")
out.append(f"\t\t{RESOURCES_PHASE_ID} /* Resources */ = {{")
out.append("\t\t\tisa = PBXResourcesBuildPhase;")
out.append("\t\t\tbuildActionMask = 2147483647;")
out.append("\t\t\tfiles = (")
for fid, bid, name, path in assets:
    out.append(f"\t\t\t\t{bid} /* {name} in Resources */,")
out.append("\t\t\t);")
out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
out.append("\t\t};")
out.append("/* End PBXResourcesBuildPhase section */")

# PBXSourcesBuildPhase
out.append("\n/* Begin PBXSourcesBuildPhase section */")
out.append(f"\t\t{SOURCES_PHASE_ID} /* Sources */ = {{")
out.append("\t\t\tisa = PBXSourcesBuildPhase;")
out.append("\t\t\tbuildActionMask = 2147483647;")
out.append("\t\t\tfiles = (")
for fid, bid, name, path in sources:
    out.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
out.append("\t\t\t);")
out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
out.append("\t\t};")
out.append("/* End PBXSourcesBuildPhase section */")

# XCBuildConfiguration
out.append("\n/* Begin XCBuildConfiguration section */")
for cid, cname, settings in [
    (PROJ_DEBUG_ID, "Debug", PROJ_DEBUG),
    (PROJ_RELEASE_ID, "Release", PROJ_RELEASE),
    (TGT_DEBUG_ID, "Debug", TGT_DEBUG),
    (TGT_RELEASE_ID, "Release", TGT_RELEASE),
]:
    out.append(f"\t\t{cid} /* {cname} */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append(fmt_settings(settings))
    out.append("\t\t\t};")
    out.append(f"\t\t\tname = {cname};")
    out.append("\t\t};")
out.append("/* End XCBuildConfiguration section */")

# XCConfigurationList
out.append("\n/* Begin XCConfigurationList section */")
out.append(f"\t\t{PROJ_CONFLIST_ID} /* Build configuration list for PBXProject \"{APP_NAME}\" */ = {{")
out.append("\t\t\tisa = XCConfigurationList;")
out.append("\t\t\tbuildConfigurations = (")
out.append(f"\t\t\t\t{PROJ_DEBUG_ID} /* Debug */,")
out.append(f"\t\t\t\t{PROJ_RELEASE_ID} /* Release */,")
out.append("\t\t\t);")
out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
out.append("\t\t\tdefaultConfigurationName = Release;")
out.append("\t\t};")
out.append(f"\t\t{TGT_CONFLIST_ID} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */ = {{")
out.append("\t\t\tisa = XCConfigurationList;")
out.append("\t\t\tbuildConfigurations = (")
out.append(f"\t\t\t\t{TGT_DEBUG_ID} /* Debug */,")
out.append(f"\t\t\t\t{TGT_RELEASE_ID} /* Release */,")
out.append("\t\t\t);")
out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
out.append("\t\t\tdefaultConfigurationName = Release;")
out.append("\t\t};")
out.append("/* End XCConfigurationList section */")

if ENABLE_FIREBASE:
    out.append("\n/* Begin XCRemoteSwiftPackageReference section */")
    out.append(f"\t\t{FB_PKGREF_ID} /* XCRemoteSwiftPackageReference \"firebase-ios-sdk\" */ = {{")
    out.append("\t\t\tisa = XCRemoteSwiftPackageReference;")
    out.append("\t\t\trepositoryURL = \"https://github.com/firebase/firebase-ios-sdk.git\";")
    out.append("\t\t\trequirement = {")
    out.append("\t\t\t\tkind = upToNextMajorVersion;")
    out.append("\t\t\t\tminimumVersion = 10.25.0;")
    out.append("\t\t\t};")
    out.append("\t\t};")
    out.append("/* End XCRemoteSwiftPackageReference section */")

    out.append("\n/* Begin XCSwiftPackageProductDependency section */")
    for p in FB_PRODUCTS:
        out.append(f"\t\t{FB_PRODDEP[p]} /* {p} */ = {{")
        out.append("\t\t\tisa = XCSwiftPackageProductDependency;")
        out.append(f"\t\t\tpackage = {FB_PKGREF_ID} /* XCRemoteSwiftPackageReference \"firebase-ios-sdk\" */;")
        out.append(f"\t\t\tproductName = {p};")
        out.append("\t\t};")
    out.append("/* End XCSwiftPackageProductDependency section */")

out.append("\t};")
out.append(f"\trootObject = {PROJECT_ID} /* Project object */;")
out.append("}")

os.makedirs(PROJ_DIR, exist_ok=True)
with open(os.path.join(PROJ_DIR, "project.pbxproj"), "w") as f:
    f.write("\n".join(out) + "\n")

print(f"Generated {PROJ_DIR}/project.pbxproj")
print(f"  sources : {len(sources)}")
print(f"  assets  : {len(assets)}")
print(f"  groups  : {len(groups)}")
if ENABLE_FIREBASE:
    print("  firebase: 已注入 SwiftPM 依赖 firebase-ios-sdk（FirebaseAuth, FirebaseFirestore）")
