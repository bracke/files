with Files.Extra_Info;
--  The info pane: whether it is open, its scroll, and the selected item's
--  extra details it shows.
package Files.Model.Info_Pane is

   --  Toggle info-pane visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Info_Pane
     (Model : in out Window_Model);

   --  Return whether the info pane is open.
   --
   --  @param Model Model to inspect.
   --  @return True when info pane is open.
   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return whether the selected item's "extra info" (folder child count,
   --  document counts, symlink target) is wanted and not computed yet: the info
   --  pane is open, no paste or listing is in flight, and the value is not
   --  cached. Files.Refresh.Ensure_Selected_Item_Extra computes it.
   --
   --  @param Model Model to inspect.
   --  @return True when the selected item's extra info should be computed.
   function Selected_Item_Needs_Extra
     (Model : Window_Model)
      return Boolean;

   --  Cache the selected item's computed extra info. A no-op unless
   --  Selected_Item_Needs_Extra holds.
   --
   --  @param Model Model whose selected item is updated in place.
   --  @param Extra The extra info (No_Info when there is nothing to show).
   procedure Set_Selected_Item_Extra
     (Model : in out Window_Model;
      Extra : Files.Extra_Info.Info);

   --  Scroll the info pane by logical text lines.
   --
   --  @param Model Model to update.
   --  @param Lines Positive values scroll down; negative values scroll up.
   procedure Scroll_Info_Pane
     (Model : in out Window_Model;
      Lines : Integer);

   --  Return the current info-pane scroll offset in logical text lines.
   --
   --  @param Model Model to inspect.
   --  @return Non-negative info-pane scroll offset.
   function Info_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural;

   --  Set the info-pane scroll offset directly (clamped externally by the
   --  renderer at draw time). Used by scrollbar drag-to-scroll.
   --
   --  @param Model Model to update.
   --  @param Lines New info-pane scroll offset in logical text lines.
   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural);

   --  After a refresh relisted the folder in view (which resets the info
   --  pane): when the primary selection is still the item at Previous's
   --  path, give the pane back its scroll (the renderer clamps it to the
   --  pane), and -- with Keep_Extra, when the item's kind, type, size and
   --  modification time are unchanged -- the extra details already read for
   --  it, rather than dropping them and reading them again.
   --
   --  @param Model Model refreshed.
   --  @param Previous The primary selected item before the refresh.
   --  @param Scroll The info pane's scroll before the refresh.
   --  @param Keep_Extra Whether details read before may still hold (False
   --    when what they depend on besides the item, such as the hidden-files
   --    setting, may have changed).
   procedure Keep_Info_Pane
     (Model      : in out Window_Model;
      Previous   : Files.Items.Directory_Item;
      Scroll     : Natural;
      Keep_Extra : Boolean);

end Files.Model.Info_Pane;
