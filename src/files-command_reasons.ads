--  Why a command cannot run now, and the message key each reason reports.
--  A leaf below both the command catalog (Files.Commands.Status decides the
--  reason) and Files.Operations (which reports the same key when it is asked
--  to run a command that cannot), so neither names the other.
package Files.Command_Reasons is
   pragma Pure;

   --  Why a command cannot run now. No_Reason is used both for an enabled
   --  command and for a disabled one with nothing worth telling the user (no
   --  undo history, a modal overlay that silently owns the keyboard).
   type Disabled_Reason is
     (No_Reason,
      Selection_Empty_Reason,
      Create_Pending_Reason,
      Trash_View_Reason,
      Recent_View_Reason,
      Not_Archive_Reason,
      Clipboard_Empty_Reason,
      Settings_Closed_Reason,
      Back_Unavailable_Reason,
      Forward_Unavailable_Reason,
      Rename_Unavailable_Reason,
      Filter_Empty_Reason,
      Root_Unselected_Reason,
      Eject_Unavailable_Reason,
      Trash_Unavailable_Reason);

   --  The localization key of the message a disabled command reports.
   --
   --  @param Reason Why the command is disabled.
   --  @return Error catalog key, or an empty string for No_Reason.
   function Reason_Key
     (Reason : Disabled_Reason)
      return String is
     (case Reason is
         when No_Reason                  => "",
         when Selection_Empty_Reason     => "error.selection.empty",
         when Create_Pending_Reason      => "error.create.pending",
         when Trash_View_Reason          => "error.command.trash_view",
         when Recent_View_Reason         => "error.command.recent_view",
         when Not_Archive_Reason         => "error.extract.not_archive",
         when Clipboard_Empty_Reason     => "error.clipboard.empty",
         when Settings_Closed_Reason     => "error.settings.closed",
         when Back_Unavailable_Reason    => "error.history.back_unavailable",
         when Forward_Unavailable_Reason => "error.history.forward_unavailable",
         when Rename_Unavailable_Reason  => "error.rename.disabled",
         when Filter_Empty_Reason        => "error.filter.empty",
         when Root_Unselected_Reason     => "error.root.selection.empty",
         when Eject_Unavailable_Reason   => "error.root.eject_unavailable",
         when Trash_Unavailable_Reason   => "error.trash.unavailable");

end Files.Command_Reasons;
