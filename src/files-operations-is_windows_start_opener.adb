separate (Files.Operations)
--  The Windows default opener is written as `cmd /c start "" {path}`. cmd
--  re-parses that command line, so a file named `x&calc` would also run
--  calc, and %VAR% expands even inside quotes. Recognize the shape and open
--  the path through the shell's own association instead, where nothing is
--  parsed. Saved settings files carry the same shape, so this covers them.
function Is_Windows_Start_Opener
  (Executable : String;
   Arguments  : Hostkit.String_Vectors.Vector)
   return Boolean is
begin
   return Hostkit.Process.Is_Shell_Start (Executable, Arguments);
end Is_Windows_Start_Opener;
