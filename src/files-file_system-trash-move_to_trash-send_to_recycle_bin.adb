separate (Files.File_System.Trash.Move_To_Trash)
--  The Recycle Bin says where the item went -- its $R path, beside the $I
--  record of where it came from -- so that is the trashed path, and Undo
--  and the trash view restore from it as from the freedesktop trash. The
--  record names the item's real place; Recorded_Path is for a trash whose
--  record is ours to write.
function Send_To_Recycle_Bin return Mutation_Result is
   Request : constant Native_Trash_Request :=
     (Backend                 => Backend,
      Path                    => To_Unbounded_String (Path),
      Requires_Native_Api     => True,
      Can_Use_Current_Process => True);
   Evaluation : constant Native_Trash_Result := Evaluate_Native_Trash (Request);
   Recycled, Ignored_Info : Files.Types.UString;
   Outcome : Hostkit.Trash.Recycle_Outcome;
begin
   if not Evaluation.Supported then
      return (Success => False, Error_Key => Evaluation.Error_Key);
   elsif Native_Trash_Refused then
      return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
   end if;
   Outcome := Hostkit.Trash.Move_To_Recycle_Bin (Path, Recycled, Ignored_Info);
   case Outcome is
      when Hostkit.Trash.Recycled =>
         Trashed_Path := Recycled;
         return (Success => True, Error_Key => Null_Unbounded_String);
      when Hostkit.Trash.Recycle_Unsupported =>
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.native_unavailable"));
      when Hostkit.Trash.Recycle_Volume_Unavailable =>
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.volume_unavailable"));
      when Hostkit.Trash.Recycle_Bin_Missing | Hostkit.Trash.Recycle_Bin_Newer_Format =>
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.recycle_bin_unusable"));
      when Hostkit.Trash.Recycle_Refused =>
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
   end case;
end Send_To_Recycle_Bin;
