separate (Files.Operations)
--  The Windows default opener is written as `cmd /c start "" {path}`. cmd
--  re-parses that command line, so a file named `x&calc` would also run
--  calc, and %VAR% expands even inside quotes. Recognize the shape and open
--  the path through the shell's own association instead, where nothing is
--  parsed. Saved settings files carry the same shape, so this covers them.
function Is_Windows_Start_Opener
  (Executable : String;
   Arguments  : Hostkit.String_Vectors.Vector)
   return Boolean
is
   use type Hostkit.Host.Kind;
   use type Ada.Containers.Count_Type;

   function Lower (Text : String) return String renames Files.Types.To_Lower;

   Program : constant String := Lower (Executable);
begin
   return Hostkit.Host.Current = Hostkit.Host.Windows
     and then Arguments.Length = 4
     and then (Program in "cmd" | "cmd.exe"
               or else (Program'Length > 8
                        and then Program (Program'Last - 7 .. Program'Last) in "\cmd.exe" | "/cmd.exe"))
     and then Lower (To_String (Arguments (1))) = "/c"
     and then Lower (To_String (Arguments (2))) = "start"
     and then To_String (Arguments (3)) = ""
     and then To_String (Arguments (4)) /= "";
end Is_Windows_Start_Opener;
