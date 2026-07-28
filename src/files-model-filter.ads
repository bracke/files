--  The filter state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Filter is

   --  Set filter text and reconcile selection.
   --
   --  @param Model Model to update.
   --  @param Text New filter text.
   procedure Set_Filter
     (Model : in out Window_Model;
      Text  : String);

   --  Return the current filter text.
   --
   --  @param Model Model to inspect.
   --  @return Filter text.
   function Filter_Text
     (Model : Window_Model)
      return String;

   --  Clear the current filter text. Resets the search scope to Filter_Here and
   --  drops any recorded search-results state.
   --
   --  @param Model Model to update.
   procedure Clear_Filter
     (Model : in out Window_Model);

   --  Return the active scope of the shared filter-bar query.
   --
   --  @param Model Model to inspect.
   --  @return Current search scope.
   function Search_Scope_Of
     (Model : Window_Model)
      return Files.Types.Search_Scope;

   --  Set the active scope of the shared filter-bar query. Does not itself run a
   --  search; callers run the matching operation and record results separately.
   --
   --  @param Model Model to update.
   --  @param Scope New search scope.
   procedure Set_Search_Scope
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope);

   --  Return whether the current view holds recursive search results rather than
   --  a plain directory listing.
   --
   --  @param Model Model to inspect.
   --  @return True when search results are shown.
   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean;

   --  Record that the current view now holds recursive search results for the
   --  given scope. Used by the name and content search operations.
   --
   --  @param Model Model to update.
   --  @param Scope Scope that produced the results.
   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope);

   --  Drop any recorded search-results state and reset the scope to Filter_Here,
   --  leaving the loaded items untouched so the caller can restore the directory.
   --
   --  @param Model Model to update.
   procedure Clear_Search_Results
     (Model : in out Window_Model);

   --  Feed a typed printable character run to the grid type-ahead buffer.
   --
   --  Appends Text to the pending type-ahead prefix and jumps the single
   --  selection to the first visible item whose name starts with the prefix,
   --  scanning from the current selection and wrapping around. Repeatedly
   --  typing the same single letter cycles through the items beginning with it.
   --  A run that matches nothing leaves the current selection untouched. Intended
   --  for use only when the file grid is focused (no text field active).
   --
   --  @param Model Model to update.
   --  @param Text Printable UTF-8 character run typed by the user.
   --  @param Matched Set True when a matching item was selected.
   procedure Type_Ahead_Input
     (Model   : in out Window_Model;
      Text    : String;
      Matched : out Boolean);

   --  Clear the pending grid type-ahead prefix.
   --
   --  @param Model Model to update.
   procedure Reset_Type_Ahead
     (Model : in out Window_Model);

   --  Return the pending grid type-ahead prefix.
   --
   --  @param Model Model to inspect.
   --  @return Current type-ahead prefix, or an empty string when idle.
   function Type_Ahead_Buffer
     (Model : Window_Model)
      return String;

   --  Focus the filter input field.
   --
   --  @param Model Model to update.
   procedure Focus_Filter_Input
     (Model : in out Window_Model);

end Files.Model.Filter;
