require 'rubygems'
require 'net/http'
require 'uri'
require 'json'

class SwClient
  attr_reader :url

  def initialize(url)
    @url = url
  end

  def results(url_with_params)
    res_url = URI.parse(url_with_params)
    Net::HTTP.get_response(res_url).body
  end

  def coll_search(id)
    query = "/select?&fq=collection:#{id}&q=*%3A*&rows=10000000&fl=id%2Cmanaged_purl_urls%2Ccollection&wt=json"
  end

  def json_parsed_resp(url, query)
    JSON.parse(results("#{url + query}"))
  end

  def parse_collection_druids(res)
    id_arr=[]
    multi_urls={}
    res["response"]["docs"].each do |i|
      ids = {}
      if /[0-9]*/.match(i["id"]) && i["managed_purl_urls"]
        multi=[]
        ids[:ckey] = i["id"]
        if i["managed_purl_urls"].length == 1
          ids[:druid] = druid_from_managed_purl(i["managed_purl_urls"].first)
        elsif i["managed_purl_urls"].length > 1
          ids[:druid] = ''
          i["managed_purl_urls"].each do |u|
            multi.push(druid_from_managed_purl(u))
          end
          multi_urls[i["id"]] = multi
        end
      elsif /[a-z]{2}[0-9]{3}[a-z]{2}[0-9]{4}/.match(i["id"])
        ids[:druid] = i["id"]
        ids[:ckey] = ''
      end
      id_arr.push(ids)
    end
    write_multi_managed_purls_file(multi_urls) if multi_urls != {}
    id_arr
  end

def parse_item_druids_no_collection(res)
    druid_ids=[]
    multi_urls={}
    res["response"]["docs"].each do |i|
      if /[0-9]*/.match(i["id"]) && i["managed_purl_urls"] && i["collection"].length < 2
        multi=[]
        if i["managed_purl_urls"].length == 1
          druid_ids.push(druid_from_managed_purl(i["managed_purl_urls"].first))
        elsif i["managed_purl_urls"].length > 1
          i["managed_purl_urls"].each do |u|
            multi.push(druid_from_managed_purl(u))
          end
          multi_urls[i["id"]] = multi
        end
      elsif /[a-z]{2}[0-9]{3}[a-z]{2}[0-9]{4}/.match(i["id"])
        druid_ids.push(i["id"])
      end
    end
    write_multi_managed_purls_file(multi_urls) if multi_urls != {}
    druid_ids
  end

  def druid_from_managed_purl(mpu)
    mpu.gsub!("\"", "")
    mpu.gsub!("http:\/\/purl.stanford.edu\/", "")
  end

  def collections_ids
    druids = []
    # SearchWorks production collection druids
    # Query is fq=collection_type:"Digital Collection", q=*:*
    # number of rows to output is 10000000
    # output fields are id and managed_purl_urls
    # output format is json
    query = "/select?&fq=collection_type%3A%22Digital+Collection%22&q=*%3A*&rows=10000000&fl=id%2Cmanaged_purl_urls%2Ccollection&wt=json"
    parse_collection_druids(json_parsed_resp(url, query))
  end

  def items_druids_no_collection
    ids = []
    # SearchWorks production item druids not in a collection
    # druid_id_query searches for records with druids as ids
    # Query is fq=id:/[a-z]{2}[0-9]{3}[a-z]{2}[0-9]{4}/,  Id is in the format of a druid
    #          fq=building_facet:"Stanford Digital Repository", From SDR
    #          fq=-collection_type:"Digital Collection",  Not a collection record
    #          fq=-collection:*,                          Not associated with a collection
    #          q=*:*
    # output field is id
    # output format is json
    druid_id_query = "/select?q=*%3A*&fq=id%3A%2F%5Ba-z%5D%7B2%7D%5B0-9%5D%7B3%7D%5Ba-z%5D%7B2%7D%5B0-9%5D%7B4%7D%2F&fq=building_facet%3A%22Stanford+Digital+Repository%22&fq=-collection_type%3A%22Digital+Collection%22&fq=-collection%3A*&rows=10000000&fl=id&wt=json"
    # ckey_id_query searches for records with catkeys as ids
    # Query is fq=id:/[0-9]*/,                            Id is in the format of a catkey (all numbers)
    #          fq=building_facet:"Stanford Digital Repository", From SDR
    #          fq=-collection_type:"Digital Collection",  Not a collection record
    #          fq=collection:sirsi,                       Associated with sirsi collection (MARC record)
    #          q=*:*
    # output fields are id, managed_purl_urls, and collection
    # output format is json
    ckey_id_query = "/select?fq=-collection_type%3A%22Digital+Collection%22&fq=collection%3A%22sirsi%22&fq=id%3A%2F%5B0-9%5D*%2F&fq=building_facet%3A%22Stanford+Digital+Repository%22&q=*%3A*&rows=100000&fl=id%2Cmanaged_purl_urls%2Ccollection&wt=json"
    ids = parse_item_druids_no_collection(json_parsed_resp(url, druid_id_query))
    ids += parse_item_druids_no_collection(json_parsed_resp(url, ckey_id_query))
    ids.uniq.sort
  end

  def collection_members(coll_druid)
    # collection members for searchworks - determined by looking for records
    # that have the collection druid or catkey
    # Query is fq=collection:coll_druid, q=*:*
    # number of rows to output is 10000000
    # output fields are id and managed_purl_urls
    # output format is csv and don't want header data wt=csv&csv.header=false
    druid_ids = []
    query = coll_search(coll_druid)
    res = json_parsed_resp(url, query)
    # if there are no results, the collection has a catkey
    if res["response"]["numFound"] == 0
      # Get the catkey by finding the corresponding managed_purl_urls
      ckey = ckey_from_druid(coll_druid)
      query = coll_search(ckey)
      res = json_parsed_resp(url, query)
    end
    parse_collection_druids(json_parsed_resp(url, query))
  end

  def ckey_from_druid(druid)
    query = "/select?fq=managed_purl_urls%3A*#{druid}&fl=id&wt=csv&&csv.header=false"
    results("#{url + query}").gsub!("\n","")
  end

  def druid_from_ckey(ckey)
    query = "/select?fq=id%3A#{ckey}&fl=managed_purl_urls&wt=csv&&csv.header=false"
    results("#{url + query}").gsub!("\n","").gsub!("http:\/\/purl.stanford.edu\/", "")
  end

  def write_multi_managed_purls_file(multi_urls)
    file = File.open("./multiple_managed_purls.txt", "w")
    multi_urls.keys.each do | id |
      file.write("#{id},")
      file.write(multi_urls[id].map { |i| i.to_s }.join(","))
      file.write("\n")
    end
    file.close unless file.nil?
  end

end
