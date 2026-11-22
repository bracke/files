separate (Files.Rendering.Build_Snapshot_Into)
   --  Combined selection total: every selected file's size plus the recursive
   --  size of each selected folder. Computed for any selection (not only when
   --  the info pane is open) so the bottom bar's total counts folder contents.
   --  Folders not yet measured, or whose measuring failed, mark the total
   --  pending (incomplete); a folder listed twice counts once. A
   --  build that kept the rows keeps the total too while neither the
   --  selection nor the folder sizes moved: with a whole large folder
   --  selected, summing it again cost every header change a walk of it.
   procedure Snapshot_Selection is
      Selection : constant Natural := Files.Model.Selection_Revision (Model);
      Sizes     : constant Natural := Files.Model.Folder_Sizes.Revision (Model);
      Total     : Long_Long_Integer := 0;
      Pending   : Boolean := False;
   begin
      if Snapshot.Selected_Count = 0 then
         Snapshot.Selection_Total_Bytes := 0;
         Snapshot.Selection_Total_Pending := False;
      elsif not (Keep_Rows
                 and then Snapshot.Total_Selection_Revision = Selection
                 and then Snapshot.Total_Sizes_Revision = Sizes)
      then
         declare
            Kept : Boolean;
         begin
            --  The model keeps the total across folder-size hand-overs; only
            --  a selection it has not seen yet is summed here, by the same
            --  rule (Folder_Sizes.Sum_Selection).
            Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Total, Pending);
            if not Kept then
               Files.Model.Folder_Sizes.Sum_Selection (Model, Total, Pending);
            end if;
         end;
         Snapshot.Selection_Total_Bytes := Total;
         Snapshot.Selection_Total_Pending := Pending;
      end if;
      Snapshot.Total_Selection_Revision := Selection;
      Snapshot.Total_Sizes_Revision := Sizes;
   end Snapshot_Selection;
