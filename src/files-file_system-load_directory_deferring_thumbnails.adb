separate (Files.File_System)
function Load_Directory_Deferring_Thumbnails
  (Path    : String;
   Classes : Files.File_Types.Classification;
   Options : Files.Types.Listing_Options)
   return Directory_Load_Result is
begin
   return Load_Directory_Filtered
     (Path, Classes, Options, null, Generate_Thumbnails => False,
      With_Signature => True);
end Load_Directory_Deferring_Thumbnails;
