#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Create the /dump directory
DUMP_DIR="/dump"
if [[ ! -d $DUMP_DIR ]]; then
    echo "Creating dump directory at $DUMP_DIR..."
    mkdir -p $DUMP_DIR
    chmod 1777 $DUMP_DIR
else
    echo "Dump directory $DUMP_DIR already exists."
fi

# Update kernel core pattern
CORE_PATTERN="kernel.core_pattern=$DUMP_DIR/core.%e.%p.%t"
if ! grep -q "$CORE_PATTERN" /etc/sysctl.conf; then
    echo "Configuring kernel core pattern..."
    echo "$CORE_PATTERN" >> /etc/sysctl.conf
    sysctl -w kernel.core_pattern="$DUMP_DIR/core.%e.%p.%t"
else
    echo "Kernel core pattern already configured."
fi

# Set unlimited core dump size for all users
LIMITS_CONF="/etc/security/limits.conf"
if ! grep -q "* soft core unlimited" $LIMITS_CONF; then
    echo "Updating core dump limits in $LIMITS_CONF..."
    echo "* soft core unlimited" >> $LIMITS_CONF
    echo "* hard core unlimited" >> $LIMITS_CONF
else
    echo "Core dump limits already set in $LIMITS_CONF."
fi

# Ensure PAM applies the limits
echo "Ensuring PAM limits are applied..."
for file in /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive; do
    if ! grep -q "pam_limits.so" $file; then
        echo "session required pam_limits.so" >> $file
    else
        echo "PAM limits already applied in $file."
    fi
done

# Configure systemd limits for core dumps
if pidof systemd > /dev/null; then
    echo "Reloading systemd configuration..."
    systemctl daemon-reexec

    # Optional: Enable persistent storage for systemd core dumps (if using systemd)
    if [[ -f /etc/systemd/coredump.conf ]]; then
        if ! grep -q "^Storage=persistent" /etc/systemd/coredump.conf; then
            echo "Configuring systemd coredump.conf for persistent storage..."
            sed -i 's/^#Storage=.*/Storage=persistent/' /etc/systemd/coredump.conf
        else
            echo "Systemd coredump.conf already configured for persistent storage."
        fi
    fi
else
    echo "Systemd is not in use, skipping systemd-specific configuration."
fi

# Apply ulimit settings persistently for all users, including root
echo "Applying unlimited core dump size for all users..."
if ! grep -q "ulimit -c unlimited" /etc/profile; then
    echo "ulimit -c unlimited" >> /etc/profile
fi
if ! grep -q "ulimit -c unlimited" /etc/bash.bashrc; then
    echo "ulimit -c unlimited" >> /etc/bash.bashrc
fi
if ! grep -q "ulimit -c unlimited" /etc/environment; then
    echo "ulimit -c unlimited" >> /etc/environment
fi

# Verify configuration in a new session
echo "Verifying configuration in a new session..."
su -c "
echo 'Current kernel core pattern:'
sysctl kernel.core_pattern
echo 'Core dump size limit:'
ulimit -c

# Test configuration
echo 'Testing core dump generation...'
echo 'Compiling and running a test crash program...'
cat << EOF > /tmp/crash.c
#include <stdio.h>
int main() {
    int *p = NULL;
    *p = 42;
    return 0;
}
EOF
gcc -o /tmp/crash /tmp/crash.c
/tmp/crash
" -s /bin/bash

# Check SELinux/AppArmor status
if command -v getenforce &> /dev/null; then
    echo "SELinux status:"
    getenforce
fi

if command -v aa-status &> /dev/null; then
    echo "AppArmor status:"
    aa-status
fi

echo "Setup complete. Check $DUMP_DIR for the generated core dump file."

