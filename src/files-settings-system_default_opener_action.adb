with Hostkit.Process;
separate (Files.Settings)
   function System_Default_Opener_Action
     (Filetype : String) return Action_Lookup_Result
   is
      Program   : Unbounded_String;
      Arguments : Hostkit.String_Vectors.Vector;
      Args      : String_Vectors.Vector;
   begin
      --  The host's own command for "open in the default application"
      --  (Hostkit.Process.Default_Opener), kept as an action so it shows and
      --  runs like any other; {path} stands for the file.
      if Hostkit.Process.Default_Opener (Filetype, "{path}", Program, Arguments) then
         for Argument of Arguments loop
            Args.Append (Argument);
         end loop;
         return
           (Found            => True,
            Action           => Make_Action (To_String (Program), Args),
            Token            => To_Unbounded_String ("system.default"),
            Error_Key        => Null_Unbounded_String,
            System_Fallback  => True);
      end if;

      return
        (Found     => False,
         Action    => Make_Action ("", String_Vectors.Empty_Vector),
         Token     => Null_Unbounded_String,
         Error_Key => To_Unbounded_String ("error.open_action.missing"),
         System_Fallback => False);
   end System_Default_Opener_Action;
