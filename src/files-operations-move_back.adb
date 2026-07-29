separate (Files.Operations)
   function Move_Back
     (Sources : Files.Types.String_Vectors.Vector;
      Targets : Files.Types.String_Vectors.Vector)
      return Boolean
   is
      Succeeded : Boolean := True;
   begin
      for Index in Sources.First_Index .. Sources.Last_Index loop
         declare
            Source : constant String := To_String (Sources.Element (Index));
            Target : constant String := To_String (Targets.Element (Index));
         begin
            if Exists_Safely (Source) and then not Exists_Safely (Target) then
               if not Files.File_System.Rename_Item (Source, Target).Success then
                  Succeeded := False;
               end if;
            else
               Succeeded := False;
            end if;
         end;
      end loop;
      return Succeeded;
   end Move_Back;
