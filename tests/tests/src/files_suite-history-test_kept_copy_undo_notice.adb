with Files.Items;
with Files.Model.Pasting;
with Files.Operations.Testing;
separate (Files_Suite.History)
   --  A failed move kept its copy on the path of an original it replaced,
   --  and the copy can no longer be verified, so the paste has no Undo. The
   --  move's own failure stays the error the paste reports; the lost Undo is
   --  a second message beside it, not a replacement for it. A paste that
   --  was only cancelled has no failure of its own, and the lost Undo is
   --  then the error.
   procedure Test_Kept_Copy_Undo_Notice (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "kept-notice-source");
      Dest     : constant String := Join (Root, "kept-notice-destination");
      Model    : Files.Model.Window_Model;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Result   : Files.Operations.Operation_Result;
   begin
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False));
      for Cancelled in Boolean loop
         Reset_Root;
         Write_Binary_File (Source, "the bytes");
         Write_Binary_File (Dest, "the bytes");
         Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Pasting.Begin_Execution (Model, Actions, Files.File_System.Drop_Move);
         --  The original the copy replaced went to the trash.
         Files.Model.Pasting.Record_Replaced_Trash
           (Model, To_Unbounded_String (Join (Root, "trashed-original")), "0:none", Dest, Verified => False);
         --  The copy's recorded identity no longer matches what is at Dest.
         Result := Files.Operations.Testing.Finalize_Paste_With_Kept_Copy
           (Model, Settings, (if Cancelled then "" else "error.drop.failed"), Dest, Source, "0:changed", "rev");
         Assert (Result.Status = Files.Operations.Operation_Failed, "the paste fails, cancelled " & Cancelled'Image);
         if Cancelled then
            Files_Suite.Support.Assert_Equal
              (To_String (Result.Error_Key), "error.paste.undo_unavailable",
               "with no failure of its own the lost Undo is the error");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Notice (Model), "", "and nothing stands beside it");
         else
            Files_Suite.Support.Assert_Equal
              (To_String (Result.Error_Key), "error.drop.failed", "the move's own failure is the paste's result");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Key (Model), "error.drop.failed", "and the error the window shows");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Notice (Model), "error.paste.undo_unavailable",
               "the lost Undo is shown beside it");
            Files.Model.Set_Error (Model, "");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Last_Error_Notice (Model), "", "a later error drops the notice");
         end if;
      end loop;
      Reset_Root;
   end Test_Kept_Copy_Undo_Notice;
