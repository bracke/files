separate (Files.Job_Drivers.Operation.Advance)
procedure Apply_Snapshot is
   use type Files.UI_Types.Search_Scope;
   Searched_Now : constant Boolean := Done.Kind in Search_Names | Search_Contents;
begin
   if Searched_Now then
      --  A new search: its results, noted afresh.
      Files.Refresh.Reinstall_Listing
        (Model, Done.Items, Done.Signature,
         Recent      => Done.Recent,
         Searched    =>
           (if Done.Kind = Search_Names then Files.UI_Types.Search_Names else Files.UI_Types.Search_Contents),
         New_Results => True);
   else
      --  The view the operation ran in, read again by the helper: search
      --  results it searched again keep the window's selection where it
      --  still is; a folder listing deferred its thumbnails, which are owed.
      Files.Refresh.Reinstall_Listing
        (Model, Done.Items, Done.Signature,
         Recent         => Done.Recent,
         Searched       => Done.Searched,
         Select_Name    => To_String (Done.Selection),
         Keep_Selection => Done.Searched /= Files.UI_Types.Filter_Here,
         Owe_Thumbnails => Done.Searched = Files.UI_Types.Filter_Here and then not Done.Recent);
   end if;
end Apply_Snapshot;
