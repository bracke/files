separate (Files.Rendering.Build_Frame_Commands)
   function Selected_Status_Text return String is
      Count : constant String :=
        Natural_Text (Snapshot.Selected_Count)
        & " "
        & Files.Localization.Text ("status.selected");
   begin
      --  When something is selected, append the combined size in parentheses,
      --  e.g. "Selected: 3 (4.5 MB)". The total includes the recursive size of
      --  selected folders; while any folder is still being measured it is
      --  marked with a trailing "..." (the total is still growing). Only spaces
      --  and punctuation are inline literals; the size comes from the formatter.
      if Snapshot.Selected_Count >= 1 then
         return
           Count & " (" & Size_Text (Snapshot.Selection_Total_Bytes)
           & (if Snapshot.Selection_Total_Pending then " ..." else "") & ")";
      else
         return Count;
      end if;
   end Selected_Status_Text;
