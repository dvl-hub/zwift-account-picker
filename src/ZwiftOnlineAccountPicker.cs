// SPDX-License-Identifier: AGPL-3.0-only
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

internal static class ZwiftOnlineAccounts {
    [STAThread]
    private static void Main() {
        string root=Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string script=Path.Combine(root,"src","Select-ZwiftOnlineAccount.ps1");
        if (!File.Exists(script)) {
            MessageBox.Show("Keep this EXE in the extracted package beside the src folder.","Zwift Online accounts");
            return;
        }
        try {
            var start=new ProcessStartInfo("powershell.exe","-STA -NoProfile -ExecutionPolicy Bypass -File \""+script+"\"");
            start.WorkingDirectory=root;
            start.UseShellExecute=false;
            start.CreateNoWindow=true;
            start.WindowStyle=ProcessWindowStyle.Hidden;
            Process.Start(start);
        } catch(Exception ex) {MessageBox.Show(ex.Message,"Zwift Online accounts");}
    }
}
