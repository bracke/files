with Files.UI_Types;

--  Which command buttons an overlay on top answers, in one table: the
--  pointer translation (Files.Events.Translate_Click) emits these commands
--  for an overlay's own controls, and the interaction layer
--  (Files.Interaction.Command_Action_Is_Current) admits only these while the
--  overlay is on top, so a click translated from an older frame cannot reach
--  the view the overlay covers.
package Files.Commands.Overlay_Buttons is

   --  The command an overlay's close button, or a click outside it, runs.
   --
   --  @param Overlay Overlay on top.
   --  @return Its closing command; No_Command for an overlay that closes only
   --    through its own dialog buttons (the progress and conflict dialogs).
   function Dismiss_Command (Overlay : Files.UI_Types.Input_Overlay) return Command_Id is
     (case Overlay is
         when Files.UI_Types.Foreground_Job_Overlay
            | Files.UI_Types.Paste_Conflict_Overlay  => No_Command,
         when Files.UI_Types.Quick_Look_Overlay      => Toggle_Quick_Look_Command,
         when Files.UI_Types.Settings_Pane_Overlay   => Toggle_Settings_Pane_Command,
         when Files.UI_Types.Tree_Pick_Overlay       => Toggle_Folder_Tree_Command,
         when Files.UI_Types.Command_Palette_Overlay
            | Files.UI_Types.Context_Menu_Overlay
            | Files.UI_Types.Label_Picker_Overlay
            | Files.UI_Types.Root_Selector_Overlay
            | Files.UI_Types.Sort_Menu_Overlay       => Close_Overlay_Command);

   --  Whether a command button may act while Overlay is on top: its
   --  Dismiss_Command, and the root selector's drive button or a sort menu
   --  row.
   --
   --  @param Overlay Overlay on top.
   --  @param Command Command a click translated to.
   --  @return True when the overlay answers Command.
   function Accepts (Overlay : Files.UI_Types.Input_Overlay; Command : Command_Id) return Boolean is
     (Command /= No_Command
      and then (Command = Dismiss_Command (Overlay)
                or else (case Overlay is
                            when Files.UI_Types.Root_Selector_Overlay => Command = Select_Drive_Command,
                            when Files.UI_Types.Sort_Menu_Overlay     => Command in Sort_Command_Id,
                            when others                               => False)));

end Files.Commands.Overlay_Buttons;
