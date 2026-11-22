separate (Files.Rendering)
procedure Copy_Rows (Target : in out View_Snapshot; Source : View_Snapshot) is
begin
   Target.Items := Source.Items;
   Target.Visible_Rows := Source.Visible_Rows;
   Target.Renamed_Rows := Source.Renamed_Rows;
   Target.Rows_Rename_Revision := Source.Rows_Rename_Revision;
   Target.Rows_Selection_Revision := Source.Rows_Selection_Revision;
   Target.Total_Selection_Revision := Source.Total_Selection_Revision;
   Target.Total_Sizes_Revision := Source.Total_Sizes_Revision;
   Target.Selection_Total_Bytes := Source.Selection_Total_Bytes;
   Target.Selection_Total_Pending := Source.Selection_Total_Pending;
   Target.Info_Key := Source.Info_Key;
   Target.Selected_Info := Source.Selected_Info;
   Target.Info_Sections := Source.Info_Sections;
   Target.Permissions_Editable := Source.Permissions_Editable;
   Target.Ownership_Editable := Source.Ownership_Editable;
end Copy_Rows;
