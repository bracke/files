separate (Files.Settings)
   function Parse_Action (Text : String) return Open_Action is
      Clean     : Unbounded_String := To_Unbounded_String (Trim (Text));
      Use_Shell : Boolean := False;
      Position  : Positive;
      Last      : Natural;
      Found     : Boolean;
      Valid     : Boolean;
      Args      : String_Vectors.Vector;
      Program   : Unbounded_String := Null_Unbounded_String;
   begin
      if Starts_With (Files.Types.To_Lower (To_String (Clean)), "shell:") then
         Use_Shell := True;
         if Length (Clean) > 6 then
            Clean := To_Unbounded_String (Trim (To_String (Clean) (7 .. Length (Clean))));
         else
            Clean := Null_Unbounded_String;
         end if;
      end if;

      if To_String (Clean) = "" then
         return Make_Action ("", Args, Use_Shell);
      end if;

      declare
         Clean_Text : constant String := To_String (Clean);
      begin
         Position := Clean_Text'First;
         declare
            Token : constant String := Next_Action_Token (Clean_Text, Position, Last, Found, Valid);
         begin
            if not Valid or else not Found then
               return Make_Action ("", Args, Use_Shell);
            end if;
            Program := To_Unbounded_String (Token);
            Position := Last;
         end;

         while Position <= Clean_Text'Last loop
            declare
               Token : constant String := Next_Action_Token (Clean_Text, Position, Last, Found, Valid);
            begin
               if not Valid then
                  return Make_Action ("", Args, Use_Shell);
               end if;
               exit when not Found;
               Args.Append (To_Unbounded_String (Token));
               Position := Last;
            end;
         end loop;
      end;

      return
        (Executable => Program,
         Arguments  => Args,
         Use_Shell  => Use_Shell);
   end Parse_Action;
