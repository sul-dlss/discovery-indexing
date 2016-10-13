#!/usr/bin/env ruby

# get a list of collection druids and catkeys from argo index
# get a list of collection druids and catleys from purl-fetcher API
# get a list of collection druids and catkeys from searchworks index

# compare those lists
#   - make a list of agree'd upon collection druids

# for each collection get druid ids with releases & catkeys from:
#   - argo index
#   - purl-fetcher
#   - searchworks index

require 'rubygems'
require 'json'
require 'net/http'
require 'uri'

def results(uri)
  res_uri = URI.parse(uri)
  resp = Net::HTTP.get_response(res_uri)
  return resp.body.split("\n")
end

def ids_from_purl_fetcher(data)
  data_ids = []
  data.each do | d |
    if !d["true_targets"].nil? && !d["true_targets"].empty?
      d["true_targets"].map!(&:downcase)
      if d["true_targets"].include? "searchworks"
        if d["catkey"].nil? || d["catkey"].empty?
          data_ids.push(d["druid"].gsub(/druid:/, ''))
        else
          data_ids.push([d["druid"].gsub(/druid:/, ''), d["catkey"]])
        end
      end
    end
  end
  data_ids
end

def druids_from_results(id_array)
  druids = []
  id_array.each do | id |
    if (id.is_a?(String))
      druids.push(id)
    elsif (id.is_a?(Array))
      druids.push(id[0])
    end
  end
  druids
end

def coll_members_from_argo(collection_ids)
  members = []
  collection_ids.each do | druid |
    members += results("https://sul-solr.stanford.edu/solr/argo3_prod/select?&fq=is_member_of_collection_ssim:%22info:fedora/druid:#{druid}%22&fl=id&rows=1000&sort=id%20asc&wt=csv&csv.header=false")
  end
  members
end

def no_pages(data)
  data["pages"]["total_pages"]
end

# Need to compare druids from argo and from sw-prod index
# Get druid, released_to array, and catkey in comma separated results
# Resulting Argo list is sorted by druid
argo_coll_results = results("https://sul-solr.stanford.edu/solr/argo3_prod/select?&fq=objectType_ssim:%22collection%22&fl=id,released_to_ssim,catkey_id_ssim&rows=10000&sort=id%20asc&wt=csv&csv.header=false")
argo_released_druids = results("https://sul-solr-a.stanford.edu/solr/argo3_prod/select?fl=id,released_to_ssim,catkey_id_ssim&fq=released_to_ssim:*&q=*:*&rows=1000000&wt=csv")


# Only care about druids released to Searchworks
released = []
argo_druids = []
argo_coll_results.each do | res |
  pieces = res.split(',')
  # Look for searchworks in the second column for each result
  # and remove druid: prefix on druid in first column
  if (!pieces[1].nil? && pieces[1].downcase == "searchworks")
    pieces[0].gsub! "druid:", ""
    released.push(pieces)
    argo_druids.push(pieces[0])
  end
end

# Get all collection druids that have been released to SearchWorks production
coll = JSON.parse(results("https://purl-fetcher-prod.stanford.edu/collections"))

coll_ids = []
coll_ids += ids_from_purl_fetcher(coll["collections"])

(2..no_pages(coll)).each do |i|
  coll = JSON.parse(results("https://purl-fetcher-prod.stanford.edu/collections?page=#{i}"))
  coll_ids += ids_from_purl_fetcher(coll["collections"])
end

coll_druids = druids_from_results(coll_ids)

# Get all druids are released to SearchWorks production
purl = JSON.parse(results("https://purl-fetcher.stanford.edu/purls?target=SearchWorks&per_page=10000"))

purl_ids = []
purl_ids += ids_from_purl_fetcher(purl["purls"])

(2..no_pages(purl)).each do |i|
  puts i
  purl = JSON.parse(results("https://purl-fetcher-prod.stanford.edu/purls?target=SearchWorks&page=#{i}&per_page=10000"))
  purl_ids += ids_from_purl_fetcher(purl["purls"])
end

purl_druids = druids_from_results(purl_ids)

# Get all IDs that are druids and all druids in the managed_purl_urls fields
lb_results = results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A%2F%5Ba-z%5D%7B2%7D%5B0-9%5D%7B3%7D%5Ba-z%5D%7B2%7D%5B0-9%5D%7B4%7D%2F&fl=id,managed_purl_urls&wt=csv&rows=10000000&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A1*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A2*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A3*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A4*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A5*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A6*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A7*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A8*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false") +
             results("http://searchworks-solr-lb:8983/solr/current/select?q=*%3A*&fq=id%3A9*&rows=10000000&fl=id%2Cmanaged_purl_urls&wt=csv&csv.header=false")

# To get members of collections
# https://sul-solr.stanford.edu/solr/argo3_prod/select?&fq=is_member_of_collection_ssim:%22info:fedora/druid:$druid%22&fl=id&rows=1000&sort=id%20asc&wt=csv&csv.header=false
# https://sul-solr.stanford.edu/solr/purl-prod/select?&fq=is_member_of_collection_ssim:"druid:$druid"&fl=id&rows=1000&sort=id%20asc&wt=csv&csv.header=false
# https://sul-solr.stanford.edu/solr/sw-preview-stage/select?&fq=collection:$druid&fl=id&rows=1000&sort=id%20asc&wt=csv&csv.header=false

sw_lb_druids = []
lb_results.each do | l |
  out = l.split(",")
  out.each do | o |
    if (o =~ /^[a-z]/)
      o.gsub!("\"", "")
      o.gsub!("http:\/\/purl.stanford.edu\/", "")
      sw_lb_druids.push(o)
    end
  end
end

sw_lb_druids = sw_lb_druids.uniq

# compare results
# argo_results format is druid, searchworks, catkeys
# purl_fetcher results format is druid, catkeys
# searchworks loadbalancer results from searching for druids as an ID and records with purl.stanford.edu in them
# the format is druid or catkey, managed_purl_urls as an array

# Get the differences in the druids from argo and purl-fetcher-prod
argo_druids_not_purl = argo_druids - purl_druids
purl_druids_not_argo = purl_druids - argo_druids
# argo_druids_not_sw_lb =
