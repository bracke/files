separate (Files.File_System)
function Execute_Native_Trash
  (Request : Native_Trash_Request)
   return Native_Trash_Result
is
   Evaluation : constant Native_Trash_Result := Evaluate_Native_Trash (Request);
   Mutation   : Mutation_Result;
begin
   case Request.Backend is
      when Trash_Windows_Recycle_Bin | Trash_Macos_Native =>
         declare
            Result : Native_Trash_Result := Evaluation;
         begin
            --  Nothing is attempted on a build that does not target this
            --  desktop: the evaluation already said so, and Attempted must
            --  stay False so a caller can tell "we tried and it refused" from
            --  "there was nothing here to try".
            if not Evaluation.Supported then
               return Result;
            end if;

            Result.Attempted := True;
            Result.Completed := Hostkit.Trash.Move_To_Trash (To_String (Request.Path));
            if not Result.Completed then
               Result.Error_Key := To_Unbounded_String ("error.trash.failed");
            end if;

            return Result;
         end;
      when others =>
         null;
   end case;

   if not Evaluation.Supported then
      return
        (Supported             => False,
         Attempted             => False,
         Completed             => False,
         Native_Binding_Available => Evaluation.Native_Binding_Available,
         Native_Binding_Status => Evaluation.Native_Binding_Status,
         Binding_Unit          => Evaluation.Binding_Unit,
         Desktop_Standard      => Evaluation.Desktop_Standard,
         Would_Delete          => Evaluation.Would_Delete,
         Uses_Recycle_Bin      => Evaluation.Uses_Recycle_Bin,
         Adapter_Name          => Evaluation.Adapter_Name,
         Native_Api_Name       => Evaluation.Native_Api_Name,
         Operation_Name        => Evaluation.Operation_Name,
         Requires_User_Consent => Evaluation.Requires_User_Consent,
         Preserves_Metadata    => Evaluation.Preserves_Metadata,
         Error_Key             => Evaluation.Error_Key);
   end if;

   Mutation := Move_To_Trash (To_String (Request.Path));
   return
     (Supported             => True,
      Attempted             => True,
      Completed             => Mutation.Success,
      Native_Binding_Available => Evaluation.Native_Binding_Available,
      Native_Binding_Status => Evaluation.Native_Binding_Status,
      Binding_Unit          => Evaluation.Binding_Unit,
      Desktop_Standard      => Evaluation.Desktop_Standard,
      Would_Delete          => False,
      Uses_Recycle_Bin      => Evaluation.Uses_Recycle_Bin,
      Adapter_Name          => Evaluation.Adapter_Name,
      Native_Api_Name       => Evaluation.Native_Api_Name,
      Operation_Name        => Evaluation.Operation_Name,
      Requires_User_Consent => Evaluation.Requires_User_Consent,
      Preserves_Metadata    => Evaluation.Preserves_Metadata,
      Error_Key             => Mutation.Error_Key);
end Execute_Native_Trash;
