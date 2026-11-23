--  The filter bar: its text, the scope its query searches, and whether the
--  view holds recursive search results in place of the folder's listing.
package Files.Model.Filtering is

   --  Set filter text and reconcile selection. While search results are
   --  shown only the field changes: they show every match whatever is
   --  typed, so the rows, scroll and selection stand. No background read
   --  depends on the text, so the listing revision stays.
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
      return Files.UI_Types.Search_Scope;

   --  Set the active scope of the shared filter-bar query. Does not itself run a
   --  search; callers run the matching operation and record results separately.
   --
   --  @param Model Model to update.
   --  @param Scope New search scope.
   procedure Set_Search_Scope
     (Model : in out Window_Model;
      Scope : Files.UI_Types.Search_Scope);

   --  Return whether the current view holds recursive search results rather than
   --  a plain directory listing.
   --
   --  @param Model Model to inspect.
   --  @return True when search results are shown.
   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean;

   --  Return the query the search results shown answer: what they are
   --  searched again for, whatever the filter field holds since.
   --
   --  @param Model Model to inspect.
   --  @return The results' query, or "" when no search results are shown.
   function Search_Query
     (Model : Window_Model)
      return String;

   --  Record that the current view now holds recursive search results for the
   --  given scope and query. Used by the name and content search operations.
   --
   --  @param Model Model to update.
   --  @param Scope Scope that produced the results.
   --  @param Query Query they answer.
   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.UI_Types.Search_Scope;
      Query : String);

   --  Drop any recorded search-results state and reset the scope to Filter_Here,
   --  leaving the loaded items untouched so the caller can restore the directory.
   --
   --  @param Model Model to update.
   procedure Clear_Search_Results
     (Model : in out Window_Model);

end Files.Model.Filtering;
