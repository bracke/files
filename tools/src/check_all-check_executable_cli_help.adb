separate (Check_All)
   procedure Check_Executable_CLI_Help is
   begin
      Run_And_Require_Output
        (Label   => "files long help",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("--help")],
         Output_Path     => Temp_Path ("help-long.txt"),
         Required_First  => "Usage: files",
         Required_Second => "--settings PATH");
      Run_And_Require_Output
        (Label   => "files short help",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("-h")],
         Output_Path     => Temp_Path ("help-short.txt"),
         Required_First  => "Usage: files",
         Required_Second => "--help, -h");
      Run_And_Require_Output
        (Label   => "files version",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("--version")],
         Output_Path     => Temp_Path ("version.txt"),
         Required_First  => "files ",
         Required_Second => "0.1.0-dev");
   end Check_Executable_CLI_Help;
