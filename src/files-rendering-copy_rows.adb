separate (Files.Rendering)
procedure Copy_Rows (Target, Source : in out View_Snapshot; Move : Boolean := False) is
begin
   --  Each kept field once: the containers taken or copied, then the
   --  scalars that say what they show.
   if Move then
      Target.Items.Move (Source.Items);
      Target.Visible_Rows.Move (Source.Visible_Rows);
      Target.Renamed_Rows.Move (Source.Renamed_Rows);
      Target.Selected_Info.Move (Source.Selected_Info);
      Target.Info_Sections.Move (Source.Info_Sections);
   else
      Target.Items := Source.Items;
      Target.Visible_Rows := Source.Visible_Rows;
      Target.Renamed_Rows := Source.Renamed_Rows;
      Target.Selected_Info := Source.Selected_Info;
      Target.Info_Sections := Source.Info_Sections;
   end if;
   Target.Rows_Rename_Revision := Source.Rows_Rename_Revision;
   Target.Rows_Selection_Revision := Source.Rows_Selection_Revision;
   Target.Total_Selection_Revision := Source.Total_Selection_Revision;
   Target.Total_Sizes_Revision := Source.Total_Sizes_Revision;
   Target.Selection_Total_Bytes := Source.Selection_Total_Bytes;
   Target.Selection_Total_Pending := Source.Selection_Total_Pending;
   Target.Info_Key := Source.Info_Key;
   Target.Permissions_Editable := Source.Permissions_Editable;
   Target.Ownership_Editable := Source.Ownership_Editable;
end Copy_Rows;
