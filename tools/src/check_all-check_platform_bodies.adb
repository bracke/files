separate (Check_All)
   procedure Check_Platform_Bodies is
   begin
      --  A source directory is a string in files.gpr, which a text check
      --  blanks unless its pattern holds a quote: look in the literals.
      Require_No_Literal_In_Unit
        (Root & "/files.gpr",
         "src/platform",
         "files.gpr must not reintroduce a per-OS source directory; per-host code is hostkit's");
      --  Nor per-OS bodies picked by naming exceptions, which is how the last
      --  two (a regular-file open and a rename's write access) came back after
      --  the directory was gone.
      Require_Not_Contains
        (Root & "/files.gpr",
         "package Naming",
         "files.gpr must not select per-OS bodies with a Naming package; per-host code is hostkit's");
      Require_In_Text
        (Root & "/alire.toml",
         "hostkit = ",
         "files must depend on hostkit, which owns every per-host body it used to carry");
   end Check_Platform_Bodies;
