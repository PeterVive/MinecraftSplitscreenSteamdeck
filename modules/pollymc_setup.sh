#!/bin/bash
# =============================================================================
# Minecraft Splitscreen Steam Deck Installer - PolyMC Setup Module
# =============================================================================
#
# This module handles the setup and optimization of PolyMC as the primary
# launcher for splitscreen gameplay, providing better offline support and
# handling of multiple simultaneous instances compared to PrismLauncher.
#
# Functions provided:
# - setup_polymc: Configure PolyMC as the primary splitscreen launcher
# - setup_polymc_launcher: Configure splitscreen launcher script for PolyMC
# - cleanup_prism_launcher: Clean up PrismLauncher files after PolyMC setup
#
# =============================================================================

# setup_polymc: Configure PolyMC as the primary launcher for splitscreen gameplay
#
# POLLYMC ADVANTAGES FOR SPLITSCREEN:
# - No forced Microsoft login requirements (offline-friendly)
# - Better handling of multiple simultaneous instances
# - Cleaner interface without authentication popups
# - More stable for automated controller-based launching
#
# PROCESS OVERVIEW:
# 1. Download PolyMC AppImage from GitHub releases
# 2. Migrate all instances from PrismLauncher to PolyMC
# 3. Copy offline accounts configuration
# 4. Test PolyMC compatibility and functionality
# 5. Set up splitscreen launcher script for PolyMC
# 6. Clean up PrismLauncher files to save space
#
# FALLBACK STRATEGY:
# If PolyMC fails at any step, we fall back to PrismLauncher
# This ensures the installation completes successfully regardless
setup_polymc() {
    print_header "🎮 SETTING UP POLYMC"

    print_progress "Downloading PolyMC for optimized splitscreen gameplay..."

    # =============================================================================
    # POLLYMC DIRECTORY INITIALIZATION
    # =============================================================================

    # Create PolyMC data directory structure
    # PolyMC stores instances, accounts, configuration, and launcher script here
    # Structure: ~/.local/share/PolyMC/{instances/, accounts.json, PolyMC AppImage}
    mkdir -p "$HOME/.local/share/PolyMC"

    # =============================================================================
    # POLLYMC APPIMAGE DOWNLOAD AND VERIFICATION
    # =============================================================================

    # Download PolyMC AppImage from official GitHub releases
    # AppImage format provides universal Linux compatibility without dependencies
    # PolyMC GitHub releases API endpoint for latest version
    # We download the x86_64 Linux AppImage which works on most modern Linux systems
    local polymc_url="$(
    curl -s https://api.github.com/repos/PolyMC/PolyMC/releases/latest |
        jq -r '.assets[] | select(.name | test("PolyMC-Linux-.*-x86_64.AppImage$")) | .browser_download_url'
    )"

    print_progress "Fetching PolyMC from GitHub releases: $(basename "$polymc_url")..."

    # DOWNLOAD WITH FALLBACK HANDLING
    # If PolyMC download fails, we continue with PrismLauncher as the primary launcher
    # This ensures installation doesn't fail completely due to network issues or GitHub downtime
    if ! wget -O "$HOME/.local/share/PolyMC/PolyMC-Linux-x86_64.AppImage" "$polymc_url"; then
        print_warning "❌ PolyMC download failed - continuing with PrismLauncher as primary launcher"
        print_info "   This is not a critical error - PrismLauncher works fine for splitscreen"
        USE_POLLYMC=false  # Global flag tracks which launcher is active
        return 0
    else
        # APPIMAGE PERMISSIONS: Make the downloaded AppImage executable
        # AppImages require execute permissions to run properly
        chmod +x "$HOME/.local/share/PolyMC/PolyMC-Linux-x86_64.AppImage"
        print_success "✅ PolyMC AppImage downloaded and configured successfully"
        USE_POLLYMC=true  # Mark PolyMC as available for further setup
    fi

    # =============================================================================
    # INSTANCE MIGRATION: Transfer all Minecraft instances from PrismLauncher
    # =============================================================================

    # INSTANCE DIRECTORY MIGRATION
    # Copy the complete instances directory structure from PrismLauncher to PolyMC
    # This includes all 4 splitscreen instances with their configurations, mods, and saves
    print_progress "Migrating PrismLauncher instances to PolyMC data directory..."

    # INSTANCES TRANSFER: Copy entire instances folder with all splitscreen configurations
    # Each instance (latestUpdate-1 through latestUpdate-4) contains:
    # - Minecraft version configuration
    # - Fabric mod loader setup
    # - All downloaded mods and their dependencies
    # - Splitscreen-specific mod configurations
    # - Instance-specific settings (memory, Java args, etc.)
    if [[ -d "$TARGET_DIR/instances" ]]; then
        cp -r "$TARGET_DIR/instances" "$HOME/.local/share/PolyMC/"
        print_success "✅ Splitscreen instances migrated to PolyMC"

        # INSTANCE COUNT VERIFICATION: Ensure all 4 instances were copied successfully
        local instance_count
        instance_count=$(find "$HOME/.local/share/PolyMC/instances" -maxdepth 1 -name "latestUpdate-*" -type d 2>/dev/null | wc -l)
        print_info "   → $instance_count splitscreen instances available in PolyMC"
    else
        print_warning "⚠️  No instances directory found in PrismLauncher - this shouldn't happen"
    fi

    # =============================================================================
    # ACCOUNT CONFIGURATION MIGRATION
    # =============================================================================

    # OFFLINE ACCOUNTS TRANSFER: Copy splitscreen player account configurations
    # The accounts.json file contains offline player profiles for Player 1-4
    # These accounts allow splitscreen gameplay without requiring multiple Microsoft accounts
    if [[ -f "$TARGET_DIR/accounts.json" ]]; then
        cp "$TARGET_DIR/accounts.json" "$HOME/.local/share/PolyMC/"
        print_success "✅ Offline splitscreen accounts copied to PolyMC"
        print_info "   → Player accounts P1, P2, P3, P4 configured for offline gameplay"
    else
        print_warning "⚠️  accounts.json not found - splitscreen accounts may need manual setup"
    fi

    # =============================================================================
    # POLLYMC CONFIGURATION: Skip Setup Wizard
    # =============================================================================

    # SETUP WIZARD BYPASS: Create PolyMC configuration using user's proven working settings
    # This uses the exact configuration from the user's working PolyMC installation
    # Guarantees compatibility and skips all setup wizard prompts
    print_progress "Configuring PolyMC with proven working settings..."

    # Get the current hostname for dynamic configuration with multiple fallback methods
    local current_hostname
    if command -v hostname >/dev/null 2>&1; then
        current_hostname=$(hostname)
    elif [[ -r /proc/sys/kernel/hostname ]]; then
        current_hostname=$(cat /proc/sys/kernel/hostname)
    elif [[ -n "$HOSTNAME" ]]; then
        current_hostname="$HOSTNAME"
    else
        current_hostname="localhost"
    fi

    cat > "$HOME/.local/share/PolyMC/polymc.cfg" <<EOF
[General]
ApplicationTheme=system
ConfigVersion=1.2
FlameKeyOverride=\$2a\$10\$bL4bIL5pUWqfcO7KQtnMReakwtfHbNKh6v1uTpKlzhwoueEJQnPnm
FlameKeyShouldBeFetchedOnStartup=false
IconTheme=pe_colored
JavaPath=${JAVA_PATH}
Language=en_US
LastHostname=${current_hostname}
MainWindowGeometry=@ByteArray(AdnQywADAAAAAAwwAAAAzAAAD08AAANIAAAMMAAAAPEAAA9PAAADSAAAAAEAAAAAB4AAAAwwAAAA8QAAD08AAANI)
MainWindowState="@ByteArray(AAAA/wAAAAD9AAAAAAAAApUAAAH8AAAABAAAAAQAAAAIAAAACPwAAAADAAAAAQAAAAEAAAAeAGkAbgBzAHQAYQBuAGMAZQBUAG8AbwBsAEIAYQByAwAAAAD/////AAAAAAAAAAAAAAACAAAAAQAAABYAbQBhAGkAbgBUAG8AbwBsAEIAYQByAQAAAAD/////AAAAAAAAAAAAAAADAAAAAQAAABYAbgBlAHcAcwBUAG8AbwBsAEIAYQByAQAAAAD/////AAAAAAAAAAA=)"
MaxMemAlloc=4096
MinMemAlloc=512
ToolbarsLocked=false
WideBarVisibility_instanceToolBar="@ByteArray(111111111,BpBQWIumr+0ABXFEarV0R5nU0iY=)"
EOF

    print_success "✅ PolyMC configured to skip setup wizard"
    print_info "   → Setup wizard will not appear on first launch"
    print_info "   → Java path and memory settings pre-configured"

    # =============================================================================
    # POLLYMC COMPATIBILITY VERIFICATION
    # =============================================================================

    # POLLYMC FUNCTIONALITY TEST: Verify PolyMC works on this system
    # Test basic AppImage execution and CLI functionality before committing to use PolyMC
    # Some older systems or restricted environments may have issues with AppImages
    print_progress "Testing PolyMC compatibility and basic functionality..."

    # APPIMAGE EXECUTION TEST: Run PolyMC with --help flag to verify it works
    # Timeout prevents hanging if AppImage has issues
    # This tests: AppImage execution, basic CLI functionality, system compatibility
    if timeout 5s "$HOME/.local/share/PolyMC/PolyMC-Linux-x86_64.AppImage" --help >/dev/null 2>&1; then
        print_success "✅ PolyMC compatibility test passed - AppImage executes properly"

        # =============================================================================
        # POLLYMC INSTANCE VERIFICATION AND FINAL SETUP
        # =============================================================================

        # INSTANCE ACCESS VERIFICATION: Confirm PolyMC can detect and access migrated instances
        # This ensures PolyMC properly recognizes the instance format from PrismLauncher
        # Both launchers use similar formats, but compatibility should be verified
        print_progress "Verifying PolyMC can access migrated splitscreen instances..."
        local poly_instances_count
        poly_instances_count=$(find "$HOME/.local/share/PolyMC/instances" -maxdepth 1 -name "latestUpdate-*" -type d 2>/dev/null | wc -l)

        if [[ "$poly_instances_count" -eq 4 ]]; then
            print_success "✅ PolyMC instance verification successful - all 4 instances accessible"
            print_info "   → latestUpdate-1, latestUpdate-2, latestUpdate-3, latestUpdate-4 ready"

            # LAUNCHER SCRIPT CONFIGURATION: Set up the splitscreen launcher for PolyMC
            # This configures the controller detection and multi-instance launch script
            setup_polymc_launcher

            # CLEANUP PHASE: Remove PrismLauncher since PolyMC is working
            # This saves significant disk space (~500MB+) and avoids launcher confusion
            # PrismLauncher was only needed for the CLI-based instance creation process
            cleanup_prism_launcher

            print_success "🎮 PolyMC is now the primary launcher for splitscreen gameplay"
            print_info "   → PrismLauncher files cleaned up to save disk space"
        else
            print_warning "⚠️  PolyMC instance verification failed - found $poly_instances_count instances instead of 4"
            print_info "   → Falling back to PrismLauncher as primary launcher"
            USE_POLLYMC=false
        fi
    else
        print_warning "❌ PolyMC compatibility test failed - AppImage execution issues detected"
        print_info "   → This may be due to system restrictions, missing dependencies, or AppImage incompatibility"
        print_info "   → Falling back to PrismLauncher for gameplay (still fully functional)"
        USE_POLLYMC=false
    fi
}

# Configure the splitscreen launcher script for PolyMC
# Downloads and modifies the launcher script to use PolyMC instead of PrismLauncher
setup_polymc_launcher() {
    print_progress "Setting up launcher script for PolyMC..."

    # LAUNCHER SCRIPT DOWNLOAD: Get the splitscreen launcher script from GitHub
    # This script handles controller detection and multi-instance launching
    if wget -O "$HOME/.local/share/PolyMC/minecraftSplitscreen.sh" \
        "https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraftSplitscreen.sh"; then
        chmod +x "$HOME/.local/share/PolyMC/minecraftSplitscreen.sh"

        # LAUNCHER SCRIPT CONFIGURATION: Modify paths to use PolyMC instead of PrismLauncher
        # Replace PrismLauncher AppImage path with PolyMC AppImage path
        sed -i 's|PrismLauncher/PrismLauncher.AppImage|PolyMC/PolyMC-Linux-x86_64.AppImage|g' \
            "$HOME/.local/share/PolyMC/minecraftSplitscreen.sh"
        # Replace PrismLauncher data directory with PolyMC data directory
        sed -i 's|/.local/share/PrismLauncher/|/.local/share/PolyMC/|g' \
            "$HOME/.local/share/PolyMC/minecraftSplitscreen.sh"

        print_success "Launcher script configured and copied to PolyMC"
    else
        print_warning "Failed to download launcher script"
    fi
}

# Clean up PrismLauncher installation after successful PolyMC setup
# This removes the temporary PrismLauncher directory to save disk space
# PrismLauncher was only needed for automated instance creation via CLI
cleanup_prism_launcher() {
    print_progress "Cleaning up PrismLauncher (no longer needed)..."

    # SAFETY: Navigate to home directory before removal operations
    # This prevents accidental deletion if we're currently in the target directory
    cd "$HOME" || return 1

    # SAFETY CHECKS: Multiple validations before removing directories
    # Ensure we're not deleting critical system directories or user home
    if [[ -d "$TARGET_DIR" && "$TARGET_DIR" != "$HOME" && "$TARGET_DIR" != "/" && "$TARGET_DIR" == *"PrismLauncher"* ]]; then
        rm -rf "$TARGET_DIR"
        print_success "Removed PrismLauncher directory: $TARGET_DIR"
        print_info "All essential files now in PolyMC directory"
    else
        print_warning "Skipped directory removal for safety: $TARGET_DIR"
    fi
}
