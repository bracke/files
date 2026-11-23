with Files.IO.Fs_Primitives;

separate (Files.Commands.Status.Status_Of)
   function Navigation_Status (Command : Navigation_Command) return Command_Status is
   begin
      case Command is
         when Navigate_Back_Command =>
            return Require (Files.Model.Can_Go_Back (Model), Back_Unavailable_Reason);
         when Navigate_Forward_Command =>
            return Require (Files.Model.Can_Go_Forward (Model), Forward_Unavailable_Reason);
         when Navigate_Parent_Command =>
            --  Enabled only in an ordinary directory view that has a parent;
            --  disabled at a filesystem root and in the trash and recent views.
            return
              All_Of
                (Ordinary_View,
                 Require (Files.IO.Fs_Primitives.Parent_Directory (Files.Model.Current_Path (Model)) /= ""));
         when Navigate_Trash_Command =>
            return Require (Files.Model.Status_Samples.Trash_Available (Model), Trash_Unavailable_Reason);
         when Empty_Trash_Command =>
            --  Emptying is only meaningful in the trash payload view and only
            --  when at least one trashed entry is present to purge.
            return Require (In_Trash_View (Model) and then Files.Model.Item_Count (Model) > 0);
         when Navigate_Recent_Command =>
            --  The recent-items view is always reachable; an empty list simply
            --  opens onto an empty view.
            return Enabled;
         when Clear_Recent_Command =>
            --  Stale recent paths are omitted from the virtual listing, so an
            --  empty view can still have persisted entries that need clearing.
            return Require (Files.Model.Recent.In_Recent_View (Model));
         when Open_Terminal_Command =>
            --  A terminal can be opened for any real directory view, but not the
            --  trash payload directory or the virtual recent view.
            return All_Of (Ordinary_View, Has_Directory);
      end case;
   end Navigation_Status;
