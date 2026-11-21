with Hostkit.Fs;

package body Files.Jobs.Helper_Modes is
   use type Hostkit.Spawn.Spawn_Outcome;

   function Mode_Of (Argument : String; Found : out Boolean) return Helper_Mode is
   begin
      for Mode in Helper_Mode loop
         if Argument = Flag (Mode) then
            Found := True;
            return Mode;
         end if;
      end loop;
      Found := False;
      return Helper_Mode'First;
   end Mode_Of;

   function Start_Helper
     (Arguments : Hostkit.String_Vectors.Vector;
      Child     : out Hostkit.Spawn.Process_Handle;
      Program   : String := "") return Boolean is
   begin
      return Hostkit.Spawn.Start
        ((if Program = "" then Hostkit.Fs.Own_Executable else Program), Arguments, (others => <>), Child)
        = Hostkit.Spawn.Spawn_Ok;
   end Start_Helper;

end Files.Jobs.Helper_Modes;
