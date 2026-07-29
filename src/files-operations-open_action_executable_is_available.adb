separate (Files.Operations)
   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean is
   begin
      if Action.Use_Shell then
         return To_String (Action.Executable) /= ""
           and then Executable_Is_Available (Shell_Executable);
      else
         return Executable_Is_Available (To_String (Action.Executable));
      end if;
   end Open_Action_Executable_Is_Available;
