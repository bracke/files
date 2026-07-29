separate (Files.File_System)
   function Execute_Drop_Import
     (Plans : Drop_Import_Plan_Vectors.Vector)
      return Mutation_Result
   is
   begin
      for Plan of Plans loop
         if not Plan.Valid then
            return
              (Success   => False,
               Error_Key =>
                 (if Length (Plan.Error_Key) > 0
                  then Plan.Error_Key
                  else To_Unbounded_String ("error.drop.failed")));
         end if;
      end loop;

      for Plan of Plans loop
         declare
            Source_Path      : constant String := To_String (Plan.Source_Path);
            Destination_Path : constant String := To_String (Plan.Destination_Path);
         begin
            if Plan.Mode = Drop_Move then
               if Source_Path /= Destination_Path then
                  begin
                     Ada.Directories.Rename (Source_Path, Destination_Path);
                  exception
                     when others =>
                        Copy_Tree (Source_Path, Destination_Path);
                        declare
                           Delete_Result : constant Mutation_Result := Delete_Permanently (Source_Path);
                        begin
                           if not Delete_Result.Success then
                              return Delete_Result;
                           end if;
                        end;
                  end;
               end if;
            else
               Copy_Tree (Source_Path, Destination_Path);
            end if;
         end;
      end loop;

      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
           Error_Key => To_Unbounded_String ("error.drop.failed"));
   end Execute_Drop_Import;
