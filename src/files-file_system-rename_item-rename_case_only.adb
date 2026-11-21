separate (Files.File_System.Rename_Item)
function Rename_Case_Only return Mutation_Result is
   Directory : constant String := Files.IO.Fs_Primitives.Parent_Directory (From_Path);

   --  Beside the original and visible, named after it ("notes
   --  (renaming).txt"), so an entry left there is found by the name the
   --  user knows; the stem is cut so the name stays storable. Built like
   --  the duplicate's "(copy)" marker: a fixed, unlocalized file name,
   --  the same on every locale.
   function Marker (Attempt : Natural) return String is
     (Files.Leaf_Names.Counted_Marker ("renaming", Attempt));

   --  A name the host will not answer for raises (Is_Taken): the
   --  rename fails rather than move onto a name that may be in use.
   function Taken (Leaf : String) return Boolean is
     (Files.IO.Fs_Primitives.Is_Taken (Hostkit.Fs.Join (Directory, Leaf)));

   Temp : Unbounded_String := Null_Unbounded_String;

   --  Whether the entry is left at the scratch name.
   --  The scratch name was free when chosen, so an entry there is ours,
   --  whether or not something took the original name meanwhile.
   function Stranded return Boolean is
     (Temp /= Null_Unbounded_String and then not Files.IO.Fs_Primitives.Entry_Is_Absent (To_String (Temp)));

   function Stranded_Result return Mutation_Result is
   begin
      Left_At := Temp;
      Failure := Rename_Stranded;
      return (Success => False, Error_Key => To_Unbounded_String (Rename_Stranded_Key));
   end Stranded_Result;
begin
   begin
      declare
         Leaf      : constant String := Mutation_Leaf_Name (From_Path);
         Is_Folder : constant Boolean := Files.IO.Fs_Primitives.Is_Plain_Directory (From_Path);
         Free      : constant String :=
           Files.Leaf_Names.First_Free
             (Files.Name_Parts.Name_Stem (Leaf, Is_Folder), Files.Name_Parts.Name_Extension (Leaf, Is_Folder),
              Marker'Access, Taken'Access,
              --  Asked once: the search may try thousands of names.
              Hostkit.Fs.Leaf_Name_Limit_At (Directory));
      begin
         if Free /= "" then
            Temp := To_Unbounded_String (Hostkit.Fs.Join (Directory, Free));
         end if;
      end;
   exception
      when Refused : Ada.Directories.Use_Error =>
         --  A scratch name that could not be looked at: no rename.
         Files.Diagnostics.Note (Refused, "Files.File_System");
         Temp := Null_Unbounded_String;
   end;

   if Temp = Null_Unbounded_String then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.rename.failed"));
   end if;

   if not Support.Move_No_Replace (From_Path, To_String (Temp)) then
      return
        (Success   => False,
         Error_Key => Files.IO.Errors.Error_Key ("error.rename.failed"));
   end if;

   begin
      if not Support.Move_No_Replace (To_String (Temp), To_Path) then
         raise Ada.Directories.Use_Error;
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System");
         declare
            --  Why the second hop failed, before the restore can say
            --  something else.
            Failed : constant Mutation_Result :=
              (Success => False, Error_Key => Files.IO.Errors.Error_Key ("error.rename.failed"));
         begin
            --  Second hop failed: restore the original name if it is
            --  still free. A competing entry must never be overwritten.
            begin
               declare
                  Restored : constant Boolean :=
                    Support.Move_No_Replace (To_String (Temp), From_Path);
                  pragma Unreferenced (Restored);
               begin
                  null;
               end;
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.File_System");
            end;
            --  Neither the new name nor the way back: say where it is.
            if Stranded then
               return Stranded_Result;
            end if;
            return Failed;
         end;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      --  A failed hop never overwrites a competing entry. The no-replace
      --  helper attempts to restore its source after a post-move error;
      --  when that failed too, the entry is at the scratch name.
      if Stranded then
         return Stranded_Result;
      end if;
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.rename.failed"));
end Rename_Case_Only;
