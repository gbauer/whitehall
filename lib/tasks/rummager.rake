namespace :rummager do
  desc "Add all published documents to the search index without removing them all first"
  task :index => ['rummager:index:detailed', 'rummager:index:government']

  task :warn_about_no_op do
    if Rails.env.development? && ENV["RUMMAGER_HOST"].blank?
      puts "Note: not actually submitting content to Rummager. Set RUMMAGER_HOST if you want to do so." 
    end
  end

  namespace :index do
    task :government => [:environment, :warn_about_no_op] do
      Rummageable.index(Whitehall.government_search_index, Whitehall.government_search_index_name)
      Rummageable.commit(Whitehall.government_search_index_name)
    end

    task :detailed => [:environment, :warn_about_no_op] do
      Rummageable.index(Whitehall.detailed_guidance_search_index, Whitehall.detailed_guidance_search_index_name)
      Rummageable.commit(Whitehall.detailed_guidance_search_index_name)
    end
  end

  desc "Remove all documents from the search index and then add all published documents"
  task :reset => ['rummager:reset:detailed', 'rummager:reset:government']

  namespace :reset do
    task :government => [:environment, :warn_about_no_op] do
      Rummageable.delete_all(Whitehall.government_search_index_name)
      Rake::Task["rummager:index:government"].invoke
    end

    task :detailed => [:environment, :warn_about_no_op] do
      Rummageable.delete_all(Whitehall.detailed_guidance_search_index_name)
      Rake::Task["rummager:index:detailed"].invoke
    end
  end
end
