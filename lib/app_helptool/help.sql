------------------------------------------------------------------------
-- TITLE:
--    helpdb2.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for helpdb2(n).
--
------------------------------------------------------------------------

-- Schema Version
PRAGMA user_version=1;

------------------------------------------------------------------------
-- Help Pages

CREATE TABLE helpdb_pages (
    -- Path of the page; it's the same as $parent/$slug.  
    -- The root page has path / and slug ''.
    path   TEXT PRIMARY KEY,

    -- The page's url suffix.  This is the name used in HREFs. 
    url    TEXT,

    -- Path of parent page, or '' for root
    parent TEXT,

    -- Slug of current page; unique for this parent.
    slug   TEXT,

    -- Leaf Node flag: 1 if the page is a leaf, and 0 otherwise.
    leaf   INTEGER DEFAULT 1,

    -- Page title
    title  TEXT,

    -- Page Alias: the 'path' of the page this is an alias to.
    alias  TEXT,

    -- The HTML text of the page, unless this is an alias.
    text   TEXT
);

CREATE INDEX helpdb_pages_parent ON helpdb_pages(parent);

------------------------------------------------------------------------
-- Images

CREATE TABLE helpdb_images (
    -- Path of the image: image/$slug.  This is the URI used in 
    -- IMG SRC.
    path     TEXT PRIMARY KEY,

    -- The page's url suffix.  This is the name used in HREFs. 
    url    TEXT,

    -- Image slug.  Every image has a unique slug, that is the last
    -- component in its path.
    slug     TEXT UNIQUE,


    -- Caption
    title    TEXT,

    -- The image data, in PNG format
    data     BLOB
);

------------------------------------------------------------------------
-- Searching

CREATE VIRTUAL TABLE helpdb_search USING fts3(
    -- Path of the page.
    path,

    -- Page title.
    title,

    -- The text of the page, with HTML stripped out.
    text
);

------------------------------------------------------------------------
-- Entity paths and reserved paths

CREATE TEMPORARY VIEW helpdb_reserved AS
SELECT '/image' AS path         UNION
SELECT '/index' AS path         UNION
SELECT path FROM helpdb_pages   UNION
SELECT path FROM helpdb_images;

