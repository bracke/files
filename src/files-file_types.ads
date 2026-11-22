with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

with Files.Types;

--  Filetype detection and icon classification.
package Files.File_Types is

   --  Return the extension of Name normalized for lookup: trimmed and
   --  lower-cased, after its last dot, none for no dot or a trailing one.
   --  Files.Name_Parts.Extension_Of is the same split with the case kept, for
   --  text shown to a person ({extension}, a rename's stem).
   --
   --  @param Name File name to inspect.
   --  @param Dotfiles A leading dot alone (.gitignore, .env) starts an
   --  extension too, as for the icon's label; otherwise such a name has none,
   --  as for filetype detection and thumbnails.
   --  @return Lower-case extension without a leading dot.
   function Normalized_Extension_Of
     (Name     : String;
      Dotfiles : Boolean := False)
      return String;

   --  Whether Extract can open a file by this name: a ZIP or 7z archive, by
   --  its extension in any case. Extract's enabling and the extraction both
   --  ask this, so the command is never offered for a file it then skips.
   --
   --  @param Name File name to inspect.
   --  @return True for a .zip or .7z name.
   function Is_Extractable_Archive (Name : String) return Boolean;

   --  A text-to-text map: what an item's filetype and icon are classified
   --  by (Files.Settings.Settings_Model keeps its mappings in this type).
   package String_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  Return a normalized extension without a leading dot.
   --
   --  @param Extension Extension text to normalize.
   --  @return Lower-case extension without a leading dot.
   function Normalize_Extension (Extension : String) return String;

   --  Return the filetype Mapping (an extension-to-filetype map such as
   --  Classification.Extension_Filetypes) gives Extension.
   --
   --  @param Mapping Extension-to-filetype map.
   --  @param Extension File extension with or without a leading dot.
   --  @return Mapped filetype, or an empty string when no mapping exists.
   function Filetype_For_Extension
     (Mapping   : String_Maps.Map;
      Extension : String)
      return String;

   --  Return the icon Mapping (a filetype-to-icon map such as
   --  Classification.Icon_Mappings) gives Filetype.
   --
   --  @param Mapping Filetype-to-icon map.
   --  @param Filetype Filetype identifier.
   --  @return Mapped icon identifier, or an empty string when no mapping exists.
   function Icon_For_Filetype
     (Mapping  : String_Maps.Map;
      Filetype : String)
      return String;

   --  The two maps an item's filetype and icon are classified by, and nothing
   --  else of the settings: what Files.File_System's listings and searches
   --  take, so the filesystem layer does not see the settings at all
   --  (Files.Settings.Classification_Of builds one from a settings model).
   type Classification is record
      --  Extension to filetype, keys normalized (Normalize_Extension).
      Extension_Filetypes : String_Maps.Map;
      --  Filetype to icon identifier, keys trimmed.
      Icon_Mappings       : String_Maps.Map;
   end record;

   --  The built-in classification: the extension and icon maps a fresh
   --  settings model starts with (Files.Settings.Default_Settings copies
   --  them), and what an item made without settings is classified by.
   --
   --  @return The default extension and icon maps.
   function Default_Classification return Classification;

   --  Determine a filetype from item kind, file name and the extension map.
   --
   --  @param Classes Extension and icon maps.
   --  @param Kind Filesystem item kind.
   --  @param Name File name to inspect.
   --  @return Filetype identifier.
   function Detect_Filetype
     (Classes : Classification;
      Kind    : Files.Types.Item_Kind;
      Name    : String)
      return String;

   --  Determine an icon identifier from item kind, filetype and the icon map.
   --
   --  @param Classes Extension and icon maps.
   --  @param Kind Filesystem item kind.
   --  @param Filetype Filetype identifier.
   --  @return Icon identifier.
   function Icon_Id_For
     (Classes  : Classification;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String;

   --  The icons an item can show: one per bundled share/files/icons definition
   --  an item is drawn with. The renderer draws exactly this, and nothing else
   --  decides it again.
   type Icon_Kind is
     (Folder_Icon,
      Link_Icon,
      Executable_Icon,
      Text_Icon,
      Markdown_Icon,
      Ada_Icon,
      Image_Icon,
      Unknown_Icon);

   --  The bundled definition's identifier for an icon: the .icon file's base name.
   --
   --  @param Icon Icon to name.
   --  @return Icon identifier such as "folder".
   function Icon_Name (Icon : Icon_Kind) return String;

   --  The identifier of the frame drawn under an item's thumbnail.
   Thumbnail_Icon_Name : constant String := "thumbnail";

   --  The icon an item is drawn with, decided once. An icon identifier naming
   --  a bundled icon (as the settings icon mapping gives it) is that icon;
   --  otherwise a folder, link or program shows its kind's icon and anything
   --  else its filetype's (see Facts_For).
   --
   --  @param Kind Filesystem item kind.
   --  @param Filetype Filetype identifier.
   --  @param Icon_Id Icon identifier from Icon_Id_For.
   --  @return The icon to draw.
   function Resolve_Icon
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Icon_Id  : String)
      return Icon_Kind;

   --  The kind a regular file of a filetype is labelled with. Extension_Label
   --  names it by its upper-case extension instead.
   type Kind_Label is
     (Extension_Label,
      Text_Label,
      Markdown_Label,
      Ada_Source_Label,
      Json_Source_Label,
      Xml_Source_Label,
      Png_Image_Label,
      Jpeg_Image_Label,
      Pdf_Document_Label,
      Word_Document_Label,
      Spreadsheet_Label,
      Archive_Label,
      Audio_Label,
      Video_Label);

   --  The catalog key of a kind label.
   --
   --  @param Label Kind label.
   --  @return Catalog key such as "info.kind.text"; "" for Extension_Label.
   function Label_Key (Label : Kind_Label) return String;

   --  The extra info line a regular file of a filetype shows when nothing more
   --  was read about it. Extension_Extra names its extension instead.
   type Extra_Fallback is
     (Extension_Extra,
      Text_Extra,
      Markdown_Extra,
      Image_Extra);

   --  The catalog key of an extra info fallback.
   --
   --  @param Extra Extra info fallback.
   --  @return Catalog key such as "info.extra.text"; "" for Extension_Extra.
   function Extra_Key (Extra : Extra_Fallback) return String;

   --  What files knows about a filetype: its kind label, its extra info
   --  fallback, and the icon a file of it shows when its icon identifier names
   --  no bundled icon.
   type Filetype_Facts is record
      Label : Kind_Label := Extension_Label;
      Extra : Extra_Fallback := Extension_Extra;
      Icon  : Icon_Kind := Unknown_Icon;
   end record;

   --  Look a filetype up in the one MIME table: an exact entry, else its
   --  image/ or text/ family, else nothing known.
   --
   --  @param Filetype Filetype identifier (MIME type).
   --  @return The filetype's facts.
   function Facts_For (Filetype : String) return Filetype_Facts;

end Files.File_Types;
