with Guikit.List_Panel;
with Guikit.Menu_Tree;

separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Overlay_Commands
     (Phase : Overlay_Draw_Phase)
   is
      procedure Draw_Root_Selector is separate;
      procedure Draw_Tree_Panel is separate;
      procedure Draw_Context_Menu is separate;
      procedure Draw_Paste_Conflict is separate;
      procedure Draw_Paste_Progress is separate;
   begin
      if Phase = Modal_Overlay_Phase and then Snapshot.Root_Selector_Open then
         Draw_Root_Selector;
      end if;

      if Phase = Persistent_Overlay_Phase and then Snapshot.Tree_Panel_Open then
         Draw_Tree_Panel;
      end if;

      if Phase = Modal_Overlay_Phase and then Snapshot.Context_Menu_Open then
         Draw_Context_Menu;
      end if;

      if Phase = Modal_Overlay_Phase and then Snapshot.Paste_Conflict_Open then
         Draw_Paste_Conflict;
      end if;

      if Phase = Modal_Overlay_Phase and then Snapshot.Paste_Progress_Open then
         Draw_Paste_Progress;
      end if;
   end Draw_Overlay_Commands;
