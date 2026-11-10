with Guikit.List_Panel;

separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Overlay_Commands is
      procedure Draw_Root_Selector is separate;
      procedure Draw_Context_Menu is separate;
      procedure Draw_Paste_Conflict is separate;
      procedure Draw_Paste_Progress is separate;
   begin
      if Snapshot.Root_Selector_Open then
         Draw_Root_Selector;
      end if;

      if Snapshot.Context_Menu_Open then
         Draw_Context_Menu;
      end if;

      if Snapshot.Paste_Conflict_Open then
         Draw_Paste_Conflict;
      end if;

      if Snapshot.Paste_Progress_Open then
         Draw_Paste_Progress;
      end if;
   end Draw_Overlay_Commands;
