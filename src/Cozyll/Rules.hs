-- | The site's rules: how every source file is compiled, routed, and combined
module Cozyll.Rules (rules) where

import Cozyll.Config (SiteConfig, projectsGroup, templatePattern)
import Cozyll.Discover (discoverGroups, discoverStandalonePages)
import Cozyll.Domain.Website (Website)
import Cozyll.Rules.Assets (processAssets)
import Cozyll.Rules.Feed (processFeeds)
import Cozyll.Rules.PostGroup (processPostGroup)
import Cozyll.Rules.Redirects (processRedirects)
import Cozyll.Rules.Showcase (processShowcaseGroup)
import Cozyll.Rules.SinglePages (page, processPage)
import Cozyll.Rules.Sitemap (processSitemap)
import Cozyll.Rules.Validate (validateNavEntries)
import Cozyll.Rules.WellKnown (processWellKnownFiles)
import Cozyll.Theme (rewritingTemplateCompiler)
import Hakyll (Rules, compile, match)

-- | Assembles the whole site from the content and configuration
rules :: SiteConfig -> Website -> Rules ()
rules cfg website = do
    match (templatePattern cfg) $ compile (rewritingTemplateCompiler cfg)
    validateNavEntries cfg
    processAssets cfg
    processWellKnownFiles cfg website
    standalone <- discoverStandalonePages cfg
    mapM_ (processPage cfg . page cfg) standalone
    groups <- discoverGroups cfg
    mapM_ (processGroup cfg) groups
    processFeeds cfg website
    processSitemap cfg
    processRedirects cfg

-- | Processes a group: posts for most groups, projects for the showcase
processGroup :: SiteConfig -> String -> Rules ()
processGroup cfg group
    | group == projectsGroup = processShowcaseGroup cfg
    | otherwise = processPostGroup cfg group
