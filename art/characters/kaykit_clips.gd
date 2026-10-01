class_name KayKitClips
extends RefCounted
## The 8 KayKit clips the game uses (D-189, ART_BIBLE §6). Mirrors tools/kaykit_import.gd CLIPS.
const NAMES: PackedStringArray = ["Idle", "Running_A", "Walking_A", "Throw", "1H_Melee_Attack_Slice_Diagonal", "2H_Ranged_Shoot", "Hit_A", "Cheer"]
const SKELETON_PATH := "Rig/Skeleton3D"  # measured: every track is "Rig/Skeleton3D:<bone>", relative to the glb root (AnimationPlayer is its direct child)
